import UIKit
import Combine

public class DMScrollBar: UIView {

    // MARK: - Public

    public let configuration: Configuration

    // MARK: - Properties

    private weak var scrollView: UIScrollView?
    private weak var delegate: DMScrollBarDelegate?
    private let scrollIndicator = ScrollBarIndicator()
    private let infoView = ScrollBarInfoView()

    private var scrollIndicatorTopConstraint: NSLayoutConstraint?
    private var scrollIndicatorTrailingConstraint: NSLayoutConstraint?
    private var scrollIndicatorWidthConstraint: NSLayoutConstraint?
    private var scrollIndicatorHeightConstraint: NSLayoutConstraint?
    private var infoViewToScrollIndicatorConstraint: NSLayoutConstraint?

    private var cancellables = Set<AnyCancellable>()
    private var hideTimer: Timer?
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    private var decelerateAnimation: TimerAnimation?

    private var scrollIndicatorOffsetOnGestureStart: CGFloat?
    private var wasInteractionStartedWithLongPress = false

    private var scrollViewLayoutGuide: UILayoutGuide? {
        configuration.indicator.insetsFollowsSafeArea ?
            scrollView?.safeAreaLayoutGuide :
            scrollView?.frameLayoutGuide
    }

    // MARK: - Initial setup

    public init(
        scrollView: UIScrollView,
        delegate: DMScrollBarDelegate? = nil,
        configuration: Configuration = .default
    ) {
        self.scrollView = scrollView
        self.configuration = configuration
        self.delegate = delegate
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupScrollView()
        setupConstraints()
        setupScrollIndicator()
        setupAdditionalInfoView()
        setupInitialAlpha()
        observeScrollViewProperties()
        addGestureRecognizers()
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        guard result == self else { return result }
        return scrollIndicator.frame.minY...scrollIndicator.frame.maxY ~= point.y ? self : nil
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private func setupConstraints() {
        guard let scrollView, let scrollViewLayoutGuide else { return }
        scrollView.addSubview(self)
        let minimumWidth: CGFloat = 20
        trailingAnchor.constraint(equalTo: scrollViewLayoutGuide.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: scrollViewLayoutGuide.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: scrollViewLayoutGuide.bottomAnchor).isActive = true
        widthAnchor.constraint(equalToConstant: max(minimumWidth, configuration.indicator.normalState.size.width)).isActive = true
    }

    private func setupInitialAlpha() {
        alpha = configuration.isAlwaysVisible ? 1 : 0
    }

    private func setupScrollView() {
        scrollView?.showsVerticalScrollIndicator = false
        scrollView?.layoutIfNeeded()
    }

    private func setupScrollIndicator() {
        addSubview(scrollIndicator)
        setup(stateConfig: configuration.indicator.normalState, indicatorTextConfig: nil)
    }

    private func setup(
        stateConfig: DMScrollBar.Configuration.Indicator.StateConfig,
        indicatorTextConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?
    ) {
        let scrollIndicatorInitialDistance = configuration.indicator.animation.animationType == .fadeAndSide && !configuration.isAlwaysVisible && alpha == 0 ?
            stateConfig.size.width :
            -stateConfig.insets.right
        setupConstraint(
            constraint: &scrollIndicatorTrailingConstraint,
            build: { scrollIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: $0) },
            value: scrollIndicatorInitialDistance
        )
        setupConstraint(
            constraint: &scrollIndicatorWidthConstraint,
            build: { scrollIndicator.widthAnchor.constraint(greaterThanOrEqualToConstant: $0) },
            value: stateConfig.size.width
        )
        setupConstraint(
            constraint: &scrollIndicatorHeightConstraint,
            build: scrollIndicator.heightAnchor.constraint(equalToConstant:),
            value: stateConfig.size.height
        )
        if scrollIndicatorTopConstraint == nil {
            let topOffset = scrollIndicatorOffsetFromScrollOffset(
                scrollView?.contentOffset.y ?? 0,
                shouldAdjustOverscrollOffset: false
            )
            scrollIndicatorTopConstraint = scrollIndicator.topAnchor.constraint(equalTo: topAnchor, constant: topOffset)
            scrollIndicatorTopConstraint?.isActive = true
        }
        scrollIndicator.setup(
            stateConfig: stateConfig,
            textConfig: indicatorTextConfig,
            accessibilityIdentifier: configuration.indicator.accessibilityIdentifier
        )
    }

    private func setupAdditionalInfoView() {
        guard let infoLabelConfig = configuration.infoLabel else { return }
        addSubview(infoView)
        infoView.setup(config: infoLabelConfig)

        let offsetLabelInitialDistance = infoLabelConfig.animation.animationType == .fadeAndSide ? 0 : infoLabelConfig.distanceToScrollIndicator
        infoViewToScrollIndicatorConstraint = scrollIndicator.leadingAnchor.constraint(equalTo: infoView.trailingAnchor, constant: offsetLabelInitialDistance)
        infoViewToScrollIndicatorConstraint?.isActive = true
        if let maximumWidth = infoLabelConfig.maximumWidth {
            infoView.widthAnchor.constraint(lessThanOrEqualToConstant: maximumWidth).isActive = true
        } else if let scrollViewLayoutGuide {
            infoView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollViewLayoutGuide.leadingAnchor, constant: 8).isActive = true
        }
        infoView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
    }

    // MARK: - Scroll view observation

    private func observeScrollViewProperties() {
        scrollView?
            .publisher(for: \.contentOffset)
            .removeDuplicates()
            .withPrevious()
            .dropFirst(2)
            .sink { [weak self] in self?.handleScrollViewOffsetChange(previousOffset: $0, newOffset: $1) }
            .store(in: &cancellables)
        scrollView?
            .panGestureRecognizer
            .publisher(for: \.state)
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] in self?.handleScrollViewGestureState($0) }
            .store(in: &cancellables)
        /**
         Next observation is needed to keep scrollBar always on top, when new subviews are added to the scrollView.
         For example, when adding scrollBar to the tableView, the tableView section headers overlaps scrollBar, and therefore scrollBar gestures are not recognized.
         layer.sublayers property is used for observation because subviews property is not KVO compliant.
         */
        scrollView?
            .publisher(for: \.layer.sublayers)
            .sink { [weak self] _ in self?.bringScrollBarToFront() }
            .store(in: &cancellables)
    }

    private func bringScrollBarToFront() {
        scrollView?.bringSubviewToFront(self)
    }

    private func handleScrollViewOffsetChange(previousOffset: CGPoint?, newOffset: CGPoint) {
        guard maxScrollViewOffset > 30 else { return } // Content size should be 30px larger than scrollView.height
        animateScrollBarShow()
        scrollIndicatorTopConstraint?.constant = scrollIndicatorOffsetFromScrollOffset(
            newOffset.y,
            shouldAdjustOverscrollOffset: panGestureRecognizer?.state == .possible && decelerateAnimation == nil
        )
        startHideTimerIfNeeded()
        /// Next code is needed to keep additional info label and scroll bar titles up-to-date during scroll view decelerate
        guard isPanGestureInactive else { return }
        if infoView.alpha == 1 {
            updateAdditionalInfoViewState(forScrollOffset: newOffset.y, previousOffset: previousOffset?.y)
        }
        if scrollIndicator.isIndicatorLabelVisible {
            updateScrollIndicatorText(
                forScrollOffset: newOffset.y,
                previousOffset: previousOffset?.y,
                textConfig: configuration.indicator.activeState.textConfig
            )
        }
    }

    private func handleScrollViewGestureState(_ state: UIGestureRecognizer.State) {
        invalidateDecelerateAnimation()
        animateAdditionalInfoViewHide()
    }

    // MARK: - Gesture Recognizers

    private func addGestureRecognizers() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panGestureRecognizer.delegate = self
        addGestureRecognizer(panGestureRecognizer)
        self.panGestureRecognizer = panGestureRecognizer

        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        longPressGestureRecognizer.minimumPressDuration = 0.2
        longPressGestureRecognizer.delegate = self
        addGestureRecognizer(longPressGestureRecognizer)
        self.longPressGestureRecognizer = longPressGestureRecognizer

        scrollView?.gestureRecognizers?.forEach {
            $0.require(toFail: panGestureRecognizer)
            $0.require(toFail: longPressGestureRecognizer)
        }
    }

    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began: handlePanGestureBegan(recognizer)
        case .changed: handlePanGestureChanged(recognizer)
        case .ended, .cancelled, .failed: handlePanGestureEnded(recognizer)
        default: break
        }
    }

    private func handlePanGestureBegan(_ recognizer: UIPanGestureRecognizer) {
        invalidateDecelerateAnimation()
        scrollIndicatorOffsetOnGestureStart = scrollIndicatorTopConstraint?.constant
        if wasInteractionStartedWithLongPress {
            wasInteractionStartedWithLongPress = false
            longPressGestureRecognizer?.cancel()
        } else {
            gestureInteractionStarted()
        }
    }

    private func handlePanGestureChanged(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        let offset = recognizer.translation(in: scrollView)
        let scrollIndicatorOffsetOnGestureStart = scrollIndicatorOffsetOnGestureStart ?? 0
        let scrollIndicatorOffset = scrollIndicatorOffsetOnGestureStart + offset.y
        let newScrollOffset = scrollOffsetFromScrollIndicatorOffset(scrollIndicatorOffset)
        let previousOffset = scrollView.contentOffset
        scrollView.setContentOffset(CGPoint(x: 0, y: newScrollOffset), animated: false)
        updateAdditionalInfoViewState(forScrollOffset: newScrollOffset, previousOffset: previousOffset.y)
        updateScrollIndicatorText(
            forScrollOffset: newScrollOffset,
            previousOffset: previousOffset.y,
            textConfig: configuration.indicator.activeState.textConfig
        )
    }

    private func handlePanGestureEnded(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        scrollIndicatorOffsetOnGestureStart = nil
        let velocity = recognizer.velocity(in: scrollView).withZeroX
        let isSignificantVelocity = abs(velocity.y) > 100
        let isOffsetInScrollBounds = maxScrollViewOffset > minScrollViewOffset ?
            minScrollViewOffset...maxScrollViewOffset ~= scrollView.contentOffset.y :
            false
        gestureInteractionEnded(willDecelerate: isSignificantVelocity || !isOffsetInScrollBounds)
        switch (isSignificantVelocity, isOffsetInScrollBounds) {
        case (true, true): startDeceleration(withVelocity: velocity)
        case (true, false): bounceScrollViewToBoundsIfNeeded(velocity: velocity)
        case (false, true):
            #if !os(visionOS)
            generateHapticFeedback()
            #endif
        case (false, false): bounceScrollViewToBoundsIfNeeded(velocity: .zero)
        }
    }

    @objc private func handleLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            wasInteractionStartedWithLongPress = true
            gestureInteractionStarted()
        case .cancelled where panGestureRecognizer?.state.isInactive == true:
            gestureInteractionEnded(willDecelerate: false)
            #if !os(visionOS)
            generateHapticFeedback()
            #endif
        case .ended, .failed:
            gestureInteractionEnded(willDecelerate: false)
            #if !os(visionOS)
            generateHapticFeedback()
            #endif
        default: break
        }
    }

    private func gestureInteractionStarted() {
        let scrollOffset = scrollOffsetFromScrollIndicatorOffset(scrollIndicatorTopConstraint?.constant ?? 0)
        updateAdditionalInfoViewState(forScrollOffset: scrollOffset, previousOffset: nil)
        invalidateHideTimer()
        #if !os(visionOS)
        generateHapticFeedback()
        #endif
        updateScrollIndicatorText(
            forScrollOffset: scrollOffset,
            previousOffset: nil,
            textConfig: configuration.indicator.activeState.textConfig
        )
        switch configuration.indicator.activeState {
        case .unchanged: break
        case .scaled(let factor): animateIndicatorStateChange(to: configuration.indicator.normalState.applying(scaleFactor: factor), textConfig: nil)
        case .custom(let config, let textConfig): animateIndicatorStateChange(to: config, textConfig: textConfig)
        }
    }

    private func gestureInteractionEnded(willDecelerate: Bool) {
        startHideTimerIfNeeded()
        switch configuration.indicator.activeState {
        case .unchanged: return
        case .custom(_, let textConfig) where textConfig != nil && willDecelerate: return
        case .custom, .scaled: animateIndicatorStateChange(to: configuration.indicator.normalState, textConfig: nil)
        }
    }

    private func animateIndicatorStateChange(
        to stateConfig: DMScrollBar.Configuration.Indicator.StateConfig,
        textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?
    ) {
        animate(duration: configuration.indicator.stateChangeAnimationDuration) { [weak self] in
            self?.setup(stateConfig: stateConfig, indicatorTextConfig: textConfig)
            self?.layoutIfNeeded()
        }
    }

    // MARK: - Deceleration & Bounce animations

    private var scale: CGFloat {
        #if os(visionOS)
        1
        #else
        UIScreen.main.scale
        #endif
    }

    private func startDeceleration(withVelocity velocity: CGPoint) {
        guard let scrollView else { return }
        let parameters = DecelerationTimingParameters(
            initialValue: scrollIndicatorTopOffset,
            initialVelocity: velocity,
            decelerationRate: UIScrollView.DecelerationRate.normal.rawValue,
            threshold: 0.5 / scale
        )

        let destination = parameters.destination
        let intersection = getIntersection(
            rect: scrollIndicatorOffsetBounds,
            segment: (scrollIndicatorTopOffset, destination)
        )

        let duration: TimeInterval = {
            if let intersection, let intersectionDuration = parameters.duration(to: intersection) {
                return intersectionDuration
            } else {
                return parameters.duration
            }
        }()

        guard configuration.shouldDecelerate else { return }

        decelerateAnimation = TimerAnimation(
            duration: duration,
            animations: { [weak self] _, time in
                guard let self else { return }
                let newY = self.scrollOffsetFromScrollIndicatorOffset(parameters.value(at: time).y)
                if abs(scrollView.contentOffset.y - newY) < parameters.threshold { return }
                scrollView.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
            }, completion: { [weak self] finished in
                guard let self else { return }
                guard finished && intersection != nil else {
                    self.invalidateDecelerateAnimation()
                    if self.configuration.indicator.activeState.textConfig != nil {
                        self.animateIndicatorStateChange(to: self.configuration.indicator.normalState, textConfig: nil)
                    }
                    return
                }
                let velocity = parameters.velocity(at: duration)
                self.bounce(withVelocity: velocity)
            })
    }

    private func bounce(withVelocity velocity: CGPoint, spring: Spring = .default) {
        guard let scrollView else { return }
        let velocityMultiplier = interval(1, maxScrollViewOffset / maxScrollIndicatorOffset, 30)
        let velocity = interval(-7000, velocity.y * velocityMultiplier, 7000)
        var previousScrollViewOffsetBounds = self.scrollViewOffsetBounds
        var restOffset = scrollView.contentOffset.clamped(to: self.scrollViewOffsetBounds)
        let displacement = scrollView.contentOffset - restOffset
        let threshold = 0.5 / scale
        var previousSafeInset = scrollView.safeAreaInsets

        let parameters = SpringTimingParameters(
            spring: spring,
            displacement: displacement,
            initialVelocity: CGPoint(x: 0, y: velocity),
            threshold: threshold
        )

        decelerateAnimation = TimerAnimation(
            duration: parameters.duration,
            animations: { _, time in
                let topSafeInsetDif = previousSafeInset.top - scrollView.safeAreaInsets.top
                let bottomSafeInsetDif = previousSafeInset.bottom - scrollView.safeAreaInsets.bottom
                previousScrollViewOffsetBounds = previousScrollViewOffsetBounds.inset(by: UIEdgeInsets(top: topSafeInsetDif, left: 0, bottom: bottomSafeInsetDif, right: 0))
                restOffset.y += self.scrollViewOffsetBounds.height - previousScrollViewOffsetBounds.height + topSafeInsetDif + bottomSafeInsetDif
                previousScrollViewOffsetBounds = self.scrollViewOffsetBounds
                previousSafeInset = scrollView.safeAreaInsets
                let offset = restOffset + parameters.value(at: time)
                scrollView.setContentOffset(offset, animated: false)
            },
            completion: { [weak self] finished in
                guard let self else { return }
                self.invalidateDecelerateAnimation()
                if self.configuration.indicator.activeState.textConfig == nil { return }
                self.animateIndicatorStateChange(to: self.configuration.indicator.normalState, textConfig: nil)
            }
        )
    }

    private func bounceScrollViewToBoundsIfNeeded(velocity: CGPoint) {
        guard let scrollView else { return }
        let overscroll: CGFloat = {
            if scrollView.contentOffset.y < minScrollViewOffset {
                return minScrollViewOffset - scrollView.contentOffset.y
            } else if scrollView.contentOffset.y > maxScrollViewOffset {
                return scrollView.contentOffset.y - maxScrollViewOffset
            }
            return 0
        }()
        if overscroll == 0 { return }
        let additionalStiffness = (overscroll / scrollView.frame.height) * 400
        bounce(withVelocity: velocity, spring: Spring(mass: 1, stiffness: 100 + additionalStiffness, dampingRatio: 1))
    }

    private func invalidateDecelerateAnimation() {
        decelerateAnimation?.invalidate()
        decelerateAnimation = nil
    }

    // MARK: - Calculations

    private var minScrollIndicatorOffset: CGFloat {
        return configuration.indicator.normalState.insets.top
    }

    private var maxScrollIndicatorOffset: CGFloat {
        return frame.height - configuration.indicator.normalState.size.height - configuration.indicator.normalState.insets.bottom
    }

    private var minScrollViewOffset: CGFloat {
        guard let scrollView else { return 0 }
        return -scrollView.contentInset.top - scrollView.safeAreaInsets.top
    }

    private var maxScrollViewOffset: CGFloat {
        guard let scrollView else { return 0 }
        return scrollView.contentSize.height - scrollView.frame.height + scrollView.safeAreaInsets.bottom + scrollView.contentInset.bottom
    }

    private var scrollIndicatorOffsetBounds: CGRect {
        CGRect(
            x: 0,
            y: minScrollIndicatorOffset,
            width: CGFloat.leastNonzeroMagnitude,
            height: maxScrollIndicatorOffset - minScrollIndicatorOffset
        )
    }

    private var scrollViewOffsetBounds: CGRect {
        CGRect(
            x: 0,
            y: minScrollViewOffset,
            width: CGFloat.leastNonzeroMagnitude,
            height: maxScrollViewOffset - minScrollViewOffset
        )
    }

    private var scrollIndicatorTopOffset: CGPoint {
        CGPoint(x: 0, y: scrollIndicatorTopConstraint?.constant ?? 0)
    }

    private func scrollOffsetFromScrollIndicatorOffset(_ scrollIndicatorOffset: CGFloat) -> CGFloat {
        let adjustedScrollIndicatorOffset = adjustedScrollIndicatorOffsetForOverscroll(scrollIndicatorOffset, isPanGestureSource: true)
        let scrollIndicatorOffsetPercent = (adjustedScrollIndicatorOffset - minScrollIndicatorOffset) / (maxScrollIndicatorOffset - minScrollIndicatorOffset)
        let scrollOffset = scrollIndicatorOffsetPercent * (maxScrollViewOffset - minScrollViewOffset) + minScrollViewOffset

        return scrollOffset
    }

    private func scrollIndicatorOffsetFromScrollOffset(_ scrollOffset: CGFloat, shouldAdjustOverscrollOffset: Bool) -> CGFloat {
        let scrollOffsetPercent = (scrollOffset - minScrollViewOffset) / (maxScrollViewOffset - minScrollViewOffset)
        let scrollIndicatorOffset = scrollOffsetPercent * (maxScrollIndicatorOffset - minScrollIndicatorOffset) + minScrollIndicatorOffset

        return shouldAdjustOverscrollOffset ?
            adjustedScrollIndicatorOffsetForOverscroll(scrollIndicatorOffset, isPanGestureSource: false) :
            scrollIndicatorOffset
    }

    private func adjustedScrollIndicatorOffsetForOverscroll(_ offset: CGFloat, isPanGestureSource: Bool) -> CGFloat {
        let indicatorToScrollRatio = scrollIndicatorOffsetBounds.height / scrollViewOffsetBounds.height
        let coefficient = isPanGestureSource ?
            RubberBand.defaultCoefficient * indicatorToScrollRatio :
            RubberBand.defaultCoefficient / indicatorToScrollRatio
        let adjustedCoefficient = interval(0.1, coefficient, RubberBand.defaultCoefficient)

        return RubberBand(
            coeff: adjustedCoefficient,
            dims: frame.size,
            bounds: scrollIndicatorOffsetBounds
        ).clamp(CGPoint(x: 0, y: offset)).y
    }

    // MARK: - Private methods

    private var isPanGestureInactive: Bool {
        return panGestureRecognizer?.state.isInactive == true
    }

    private func scrollIndicatorOffset(forContentOffset contentOffset: CGFloat) -> CGFloat {
        return contentOffset + scrollIndicatorTopOffset.y + infoView.frame.height / 2
    }

    private func startHideTimerIfNeeded() {
        guard isPanGestureInactive else { return }
        invalidateHideTimer()
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.hideTimeInterval,
            repeats: false
        ) { [weak self] _ in
            self?.animateScrollBarHide()
            self?.invalidateHideTimer()
        }
    }

    private func invalidateHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func updateAdditionalInfoViewState(forScrollOffset scrollViewOffset: CGFloat, previousOffset: CGFloat?) {
        if configuration.infoLabel == nil { return }
        guard let offsetLabelText = delegate?.infoLabelText(
            forContentOffset: scrollViewOffset,
            scrollIndicatorOffset: scrollIndicatorOffset(forContentOffset: scrollViewOffset)
        ) else { return animateAdditionalInfoViewHide() }
        animateAdditionalInfoViewShow()
        let direction: CATransitionSubtype? = {
            guard let previousOffset else { return nil }
            return scrollViewOffset > previousOffset ? .fromTop : .fromBottom
        }()
        infoView.updateText(text: offsetLabelText, direction: direction)
    }

    private func updateScrollIndicatorText(
        forScrollOffset scrollViewOffset: CGFloat,
        previousOffset: CGFloat?,
        textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?
    ) {
        let direction: CATransitionSubtype? = {
            guard let previousOffset else { return nil }
            return scrollViewOffset > previousOffset ? .fromTop : .fromBottom
        }()
        scrollIndicator.updateScrollIndicatorText(
            direction: direction,
            scrollBarLabelText: delegate?.scrollBarText(
                forContentOffset: scrollViewOffset,
                scrollIndicatorOffset: scrollIndicatorOffset(forContentOffset: scrollViewOffset)
            ),
            textConfig: textConfig
        )
    }

    private func animateScrollBarShow() {
        guard alpha == 0 else { return }
        setup(stateConfig: configuration.indicator.normalState, indicatorTextConfig: nil)
        layoutIfNeeded()
        animate(duration: configuration.indicator.animation.showDuration) { [weak self] in
            guard let self else { return }
            self.alpha = 1
            guard self.configuration.indicator.animation.animationType == .fadeAndSide else { return }
            self.scrollIndicatorTrailingConstraint?.constant = -self.configuration.indicator.normalState.insets.right
            self.layoutIfNeeded()
        }
    }

    private func animateScrollBarHide() {
        if alpha == 0 { return }
        defer { animateAdditionalInfoViewHide() }
        if configuration.isAlwaysVisible { return  }
        animate(duration: configuration.indicator.animation.hideDuration) { [weak self] in
            guard let self else { return }
            self.alpha = 0
            guard self.configuration.indicator.animation.animationType == .fadeAndSide else { return }
            self.scrollIndicatorTrailingConstraint?.constant = self.configuration.indicator.normalState.size.width
            self.layoutIfNeeded()
        }
    }

    private func animateAdditionalInfoViewShow() {
        guard let infoLabelConfig = configuration.infoLabel, infoView.alpha == 0 else { return }
        animate(duration: infoLabelConfig.animation.showDuration) { [weak self] in
            self?.infoView.alpha = 1
            guard infoLabelConfig.animation.animationType == .fadeAndSide else { return }
            self?.infoViewToScrollIndicatorConstraint?.constant = infoLabelConfig.distanceToScrollIndicator
            self?.layoutIfNeeded()
        }
    }

    private func animateAdditionalInfoViewHide() {
        guard let infoLabelConfig = configuration.infoLabel, infoView.alpha != 0 else { return }
        animate(duration: infoLabelConfig.animation.hideDuration) { [weak self] in
            self?.infoView.alpha = 0
            guard infoLabelConfig.animation.animationType == .fadeAndSide else { return }
            self?.infoViewToScrollIndicatorConstraint?.constant = 0
            self?.layoutIfNeeded()
        }
    }

    private func animate(duration: CGFloat, animation: @escaping () -> Void) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
            animations: animation
        )
    }
}

// MARK: - UIGestureRecognizerDelegate

extension DMScrollBar: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == longPressGestureRecognizer ||
            gestureRecognizer == longPressGestureRecognizer && otherGestureRecognizer == panGestureRecognizer
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return scrollIndicator.frame.minY...scrollIndicator.frame.maxY ~= touch.location(in: self).y
    }
}
