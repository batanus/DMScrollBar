import UIKit
import Combine

public class DMScrollBar: UIView {

    // MARK: - Public

    public let configuration: Configuration

    // MARK: - Properties

    private weak var scrollView: UIScrollView?
    private weak var delegate: DMScrollBarDelegate?
    private let scrollIndicator = UIView()
    private let additionalInfoView = UIView()
    private let offsetLabel = UILabel()
    private var indicatorImage: UIImageView?

    private var scrollIndicatorTopConstraint: NSLayoutConstraint?
    private var scrollIndicatorTrailingConstraint: NSLayoutConstraint?
    private var scrollIndicatorWidthConstraint: NSLayoutConstraint?
    private var scrollIndicatorHeightConstraint: NSLayoutConstraint?
    private var offsetLabelTrailingConstraint: NSLayoutConstraint?
    private var indicatorImageWidthConstraint: NSLayoutConstraint?
    private var indicatorImageHeightConstraint: NSLayoutConstraint?
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
    }

    private func setupScrollIndicator() {
        addSubview(scrollIndicator)
        scrollIndicator.translatesAutoresizingMaskIntoConstraints = false
        setup(stateConfig: configuration.indicator.normalState)
    }

    private func setup(stateConfig: DMScrollBar.Configuration.Indicator.StateConfig) {
        scrollIndicator.backgroundColor = stateConfig.backgroundColor
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
            build: scrollIndicator.widthAnchor.constraint(equalToConstant:),
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
                shouldAdjustOverscrollOffset: true
            )
            scrollIndicatorTopConstraint = scrollIndicator.topAnchor.constraint(equalTo: topAnchor, constant: topOffset)
            scrollIndicatorTopConstraint?.isActive = true
        }
        scrollIndicator.layer.maskedCorners = stateConfig.roundedCorners.corners.cornerMask
        scrollIndicator.layer.cornerRadius = cornerRadius(
            from: stateConfig.roundedCorners.radius,
            viewSize: stateConfig.size
        )
        setupIndicatorImage(image: stateConfig.image, size: stateConfig.imageSize)
    }

    private func setupIndicatorImage(image: UIImage?, size: CGSize) {
        guard let image else {
            indicatorImage?.alpha = 0
            return
        }
        let imageView: UIImageView = {
            if let indicatorImage { return indicatorImage }
            let imageView = UIImageView()
            scrollIndicator.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.centerXAnchor.constraint(equalTo: scrollIndicator.centerXAnchor).isActive = true
            imageView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
            return imageView
        }()
        imageView.alpha = 1
        imageView.image = image
        setupConstraint(
            constraint: &indicatorImageWidthConstraint,
            build: imageView.widthAnchor.constraint(equalToConstant:),
            value: size.width
        )
        setupConstraint(
            constraint: &indicatorImageHeightConstraint,
            build: imageView.heightAnchor.constraint(equalToConstant:),
            value: size.height
        )
        self.indicatorImage = imageView
    }

    private func setupConstraint(constraint: inout NSLayoutConstraint?, build: (CGFloat) -> NSLayoutConstraint, value: CGFloat) {
        if let constraint {
            constraint.constant = value
        } else {
            constraint = build(value)
            constraint?.isActive = true
        }
    }

    private func setupAdditionalInfoView() {
        addSubview(additionalInfoView)
        additionalInfoView.addSubview(offsetLabel)

        let textInsets = configuration.infoLabel.textInsets
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false
        offsetLabel.font = configuration.infoLabel.font
        offsetLabel.textColor = configuration.infoLabel.textColor
        offsetLabel.topAnchor.constraint(equalTo: additionalInfoView.topAnchor, constant: textInsets.top).isActive = true
        offsetLabel.bottomAnchor.constraint(equalTo: additionalInfoView.bottomAnchor, constant: -textInsets.bottom).isActive = true
        offsetLabel.leadingAnchor.constraint(equalTo: additionalInfoView.leadingAnchor, constant: textInsets.left).isActive = true
        offsetLabel.trailingAnchor.constraint(equalTo: additionalInfoView.trailingAnchor, constant: -textInsets.right).isActive = true

        additionalInfoView.translatesAutoresizingMaskIntoConstraints = false
        additionalInfoView.backgroundColor = configuration.infoLabel.backgroundColor
        let offsetLabelInitialDistance = configuration.infoLabel.animation.animationType == .fadeAndSide ? 0 : configuration.infoLabel.distanceToScrollIndicator
        offsetLabelTrailingConstraint = scrollIndicator.leadingAnchor.constraint(equalTo: additionalInfoView.trailingAnchor, constant: offsetLabelInitialDistance)
        offsetLabelTrailingConstraint?.isActive = true
        if let maximumWidth = configuration.infoLabel.maximumWidth {
            additionalInfoView.widthAnchor.constraint(lessThanOrEqualToConstant: maximumWidth).isActive = true
        } else if let scrollViewLayoutGuide {
            additionalInfoView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollViewLayoutGuide.leadingAnchor, constant: 8).isActive = true
        }
        additionalInfoView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
        additionalInfoView.layer.maskedCorners = configuration.infoLabel.roundedCorners.corners.cornerMask
        additionalInfoView.layer.cornerRadius = cornerRadius(
            from: configuration.infoLabel.roundedCorners.radius,
            viewSize: CGSize(
                width: configuration.infoLabel.maximumWidth ?? CGFloat.greatestFiniteMagnitude,
                height: configuration.infoLabel.font.lineHeight + textInsets.top + textInsets.bottom
            )
        )

        additionalInfoView.alpha = 0
        additionalInfoView.clipsToBounds = true
    }

    private func cornerRadius(from radius: DMScrollBar.RoundedCorners.Radius, viewSize: CGSize) -> CGFloat {
        switch radius {
        case .notRounded: return 0
        case .rounded: return min(viewSize.height, viewSize.width) / 2
        case .custom(let radius): return radius
        }
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
        guard let scrollView, scrollView.frame.height < scrollView.contentSize.height else { return }
        animateScrollBarShow()
        scrollIndicatorTopConstraint?.constant = scrollIndicatorOffsetFromScrollOffset(
            newOffset.y,
            shouldAdjustOverscrollOffset: panGestureRecognizer?.state == .possible && decelerateAnimation == nil
        )
        startHideTimerIfNeeded()
        /// Next code is needed to keep additional info label title up-to-date during scroll view decelerate
        guard additionalInfoView.alpha == 1 && isPanGestureInactive else { return }
        updateAdditionalInfoViewState(forScrollOffset: newOffset.y, previousOffset: previousOffset?.y)
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
        scrollView?.panGestureRecognizer.require(toFail: panGestureRecognizer)

        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        longPressGestureRecognizer.minimumPressDuration = 0.2
        longPressGestureRecognizer.delegate = self
        addGestureRecognizer(longPressGestureRecognizer)
        self.longPressGestureRecognizer = longPressGestureRecognizer
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
    }

    private func handlePanGestureEnded(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        scrollIndicatorOffsetOnGestureStart = nil
        gestureInteractionEnded()
        let velocity = recognizer.velocity(in: scrollView).withZeroX
        let isSignificantVelocity = abs(velocity.y) > 100
        let isOffsetInScrollBounds = minScrollViewOffset...maxScrollViewOffset ~= scrollView.contentOffset.y
        switch (isSignificantVelocity, isOffsetInScrollBounds) {
        case (true, true): startDeceleration(withVelocity: velocity)
        case (true, false): bounceScrollViewToBoundsIfNeeded(velocity: velocity)
        case (false, true): generateHapticFeedback()
        case (false, false): bounceScrollViewToBoundsIfNeeded(velocity: .zero)
        }
    }

    @objc private func handleLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            wasInteractionStartedWithLongPress = true
            gestureInteractionStarted()
        case .cancelled where panGestureRecognizer?.state.isInactive == true:
            gestureInteractionEnded()
            generateHapticFeedback()
        case .ended, .failed:
            gestureInteractionEnded()
            generateHapticFeedback()
        default: break
        }
    }

    private func gestureInteractionStarted() {
        let scrollOffset = scrollOffsetFromScrollIndicatorOffset(scrollIndicatorTopConstraint?.constant ?? 0)
        updateAdditionalInfoViewState(forScrollOffset: scrollOffset, previousOffset: nil)
        invalidateHideTimer()
        generateHapticFeedback()
        animateIndicatorStateChange(to: configuration.indicator.activeState)
    }

    private func gestureInteractionEnded() {
        startHideTimerIfNeeded()
        animateIndicatorStateChange(to: configuration.indicator.normalState)
    }

    private func animateIndicatorStateChange(to stateConfig: DMScrollBar.Configuration.Indicator.StateConfig) {
        animate(duration: 0.3) { [weak self] in
            self?.setup(stateConfig: stateConfig)
            self?.layoutIfNeeded()
        }
    }

    // MARK: - Decelartion & Bounce animations

    private func startDeceleration(withVelocity velocity: CGPoint) {
        guard let scrollView else { return }
        let parameters = DecelerationTimingParameters(
            initialValue: scrollIndicatorTopOffset,
            initialVelocity: velocity,
            decelerationRate: UIScrollView.DecelerationRate.normal.rawValue,
            threshold: 0.5 / UIScreen.main.scale
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

        decelerateAnimation = TimerAnimation(
            duration: duration,
            animations: { [weak self] _, time in
                guard let self else { return }
                let newY = self.scrollOffsetFromScrollIndicatorOffset(parameters.value(at: time).y)
                scrollView.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
            }, completion: { [weak self] finished in
                guard let self else { return }
                guard finished && intersection != nil else { return self.invalidateDecelerateAnimation() }
                let velocity = parameters.velocity(at: duration)
                self.bounce(withVelocity: velocity)
            })
    }

    private func bounce(withVelocity velocity: CGPoint, spring: Spring = .default) {
        guard let scrollView else { return }
        let velocityMultiplier = interval(1, maxScrollViewOffset / maxScrollIndicatorOffset, 30)
        let velocity = interval(-7000, velocity.y * velocityMultiplier, 7000)
        var scrollViewOffsetBounds = self.scrollViewOffsetBounds
        var restOffset = scrollView.contentOffset.clamped(to: self.scrollViewOffsetBounds)
        let displacement = scrollView.contentOffset - restOffset
        let threshold = 0.5 / UIScreen.main.scale

        let parameters = SpringTimingParameters(
            spring: spring,
            displacement: displacement,
            initialVelocity: CGPoint(x: 0, y: velocity),
            threshold: threshold
        )

        decelerateAnimation = TimerAnimation(
            duration: parameters.duration,
            animations: { _, time in
                restOffset.y += self.scrollViewOffsetBounds.height - scrollViewOffsetBounds.height
                scrollViewOffsetBounds = self.scrollViewOffsetBounds
                let offset = restOffset + parameters.value(at: time)
                scrollView.setContentOffset(offset, animated: false)
            },
            completion: { [weak self] finished in
                self?.invalidateDecelerateAnimation()
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
        let additionalStiffnes = (overscroll / scrollView.frame.height) * 400
        bounce(withVelocity: velocity, spring: Spring(mass: 1, stiffness: 100 + additionalStiffnes, dampingRatio: 1))
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
        let adjustedScrollIndicatorOffset = adjustedScrollIndicatorOffsetForOverscroll(scrollIndicatorOffset)
        let scrollIndicatorOffsetPercent = (adjustedScrollIndicatorOffset - minScrollIndicatorOffset) / (maxScrollIndicatorOffset - minScrollIndicatorOffset)
        let scrollOffset = scrollIndicatorOffsetPercent * (maxScrollViewOffset - minScrollViewOffset) + minScrollViewOffset

        return scrollOffset
    }

    private func scrollIndicatorOffsetFromScrollOffset(_ scrollOffset: CGFloat, shouldAdjustOverscrollOffset: Bool) -> CGFloat {
        let scrollOffsetPercent = (scrollOffset - minScrollViewOffset) / (maxScrollViewOffset - minScrollViewOffset)
        let scrollIndicatorOffset = scrollOffsetPercent * (maxScrollIndicatorOffset - minScrollIndicatorOffset) + minScrollIndicatorOffset

        return shouldAdjustOverscrollOffset ?
            adjustedScrollIndicatorOffsetForOverscroll(scrollIndicatorOffset) :
            scrollIndicatorOffset
    }

    private func adjustedScrollIndicatorOffsetForOverscroll(_ offset: CGFloat) -> CGFloat {
        if offset < scrollIndicatorOffsetBounds.minY {
            let adjustedOffset = scrollIndicatorOffsetBounds.minY - offset
            return scrollIndicatorOffsetBounds.minY - abs(adjustedOffset) / 3
        } else if offset > scrollIndicatorOffsetBounds.maxY {
            let adjustedOffset = scrollIndicatorOffsetBounds.maxY - offset
            return scrollIndicatorOffsetBounds.maxY + abs(adjustedOffset) / 3
        }

        return offset
    }

    // MARK: - Private methods

    private var isPanGestureInactive: Bool {
        return panGestureRecognizer?.state.isInactive == true
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
        guard let offsetLabelText = delegate?.indicatorTitle(forOffset: scrollViewOffset) else { return animateAdditionalInfoViewHide() }
        animateAdditionalInfoViewShow()
        if offsetLabelText == offsetLabel.text { return }
        let direction: CATransitionSubtype? = {
            guard let previousOffset else { return nil }
            return scrollViewOffset > previousOffset ? .fromTop : .fromBottom
        }()
        offsetLabel.setup(text: offsetLabelText, direction: direction)
        additionalInfoView.layoutIfNeeded()
        generateHapticFeedback(style: .light)
    }

    private func animateScrollBarShow() {
        guard alpha == 0 else { return }
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
        guard additionalInfoView.alpha == 0 else { return }
        animate(duration: configuration.infoLabel.animation.showDuration) { [weak self] in
            guard let self else { return }
            self.additionalInfoView.alpha = 1
            guard self.configuration.infoLabel.animation.animationType == .fadeAndSide else { return }
            self.offsetLabelTrailingConstraint?.constant = self.configuration.infoLabel.distanceToScrollIndicator
            self.layoutIfNeeded()
        }
    }

    private func animateAdditionalInfoViewHide() {
        if additionalInfoView.alpha == 0 { return }
        animate(duration: configuration.infoLabel.animation.hideDuration) { [weak self] in
            guard let self else { return }
            self.additionalInfoView.alpha = 0
            guard self.configuration.infoLabel.animation.animationType == .fadeAndSide else { return }
            self.offsetLabelTrailingConstraint?.constant = 0
            self.layoutIfNeeded()
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

    private func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - UIGestureRecognizerDelegateg

extension DMScrollBar: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == longPressGestureRecognizer ||
            gestureRecognizer == longPressGestureRecognizer && otherGestureRecognizer == panGestureRecognizer
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return scrollIndicator.frame.minY...scrollIndicator.frame.maxY ~= touch.location(in: self).y
    }
}

private extension DMScrollBar.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        switch self {
        case .topLeft: return .layerMinXMinYCorner
        case .bottomLeft: return .layerMinXMaxYCorner
        case .topRight: return .layerMaxXMinYCorner
        case .bottomRight: return .layerMaxXMaxYCorner
        }
    }
}

private extension Sequence where Element == DMScrollBar.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        CACornerMask(map(\.cornerMask))
    }
}
