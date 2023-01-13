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
    private var indicatorImageLabelStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    private var indicatorImage: UIImageView?
    private var indicatorLabel: UILabel?

    private var scrollIndicatorTopConstraint: NSLayoutConstraint?
    private var scrollIndicatorTrailingConstraint: NSLayoutConstraint?
    private var scrollIndicatorWidthConstraint: NSLayoutConstraint?
    private var scrollIndicatorHeightConstraint: NSLayoutConstraint?
    private var offsetLabelTrailingConstraint: NSLayoutConstraint?
    private var indicatorImageWidthConstraint: NSLayoutConstraint?
    private var indicatorImageHeightConstraint: NSLayoutConstraint?
    private var indicatorImageLabelStackViewLeadingConstraint: NSLayoutConstraint?
    private var indicatorImageLabelStackViewTrailingConstraint: NSLayoutConstraint?
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
        scrollIndicator.clipsToBounds = true
        setup(stateConfig: configuration.indicator.normalState)
        setupIndicatorImageAndText(image: configuration.indicator.normalState.image, textConfig: nil, imageSize: configuration.indicator.normalState.imageSize)
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
        scrollIndicator.layer.maskedCorners = stateConfig.roundedCorners.corners.cornerMask
        scrollIndicator.layer.cornerRadius = cornerRadius(
            from: stateConfig.roundedCorners.radius,
            viewSize: stateConfig.size
        )
    }

    private func setupIndicatorImageAndText(image: UIImage?, textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?, imageSize: CGSize) {
        if indicatorImageLabelStackView.superview == nil {
            scrollIndicator.addSubview(indicatorImageLabelStackView)
            let centerX = indicatorImageLabelStackView.centerXAnchor.constraint(equalTo: scrollIndicator.centerXAnchor)
            centerX.priority = .init(999)
            centerX.isActive = true
            indicatorImageLabelStackView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
        }
        let defaultInset: CGFloat = 8
        let leadingInset: CGFloat = {
            guard let textConfig else { return 0 }
            return image == nil ? textConfig.insets.left : defaultInset
        }()
        setupConstraint(
            constraint: &indicatorImageLabelStackViewLeadingConstraint,
            build: { indicatorImageLabelStackView.leadingAnchor.constraint(equalTo: scrollIndicator.leadingAnchor, constant: $0) },
            value: leadingInset
        )
        setupConstraint(
            constraint: &indicatorImageLabelStackViewTrailingConstraint,
            build: { scrollIndicator.trailingAnchor.constraint(equalTo: indicatorImageLabelStackView.trailingAnchor, constant: $0) },
            value: textConfig != nil ? textConfig?.insets.right ?? defaultInset : 0
        )
        setupIndicatorImageViewState(image: image, size: imageSize)
        setupIndicatorLabelState(config: textConfig)
    }

    private func setupIndicatorImageViewState(image: UIImage?, size: CGSize) {
        buildIndicatorImageViewIfNeeded()
        if let image {
            indicatorImage?.isHidden = false
            indicatorImage?.alpha = 1
            indicatorImage?.image = image
            setupConstraint(
                constraint: &indicatorImageWidthConstraint,
                build: indicatorImage?.widthAnchor.constraint(equalToConstant:),
                value: size.width,
                priority: .init(999)
            )
            setupConstraint(
                constraint: &indicatorImageHeightConstraint,
                build: indicatorImage?.heightAnchor.constraint(equalToConstant:),
                value: size.height
            )
        } else {
            indicatorImage?.isHidden = true
            indicatorImage?.alpha = 0
        }
    }

    private func setupIndicatorLabelState(config: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?) {
        buildIndicatorLabelIfNeeded()
        if let config {
            showIndicatorLabel()
            indicatorLabel?.font = config.font
            indicatorLabel?.textColor = config.color
            indicatorImageLabelStackView.spacing = config.insets.left
        } else {
            hideIndicatorLabel()
        }
    }

    private func buildIndicatorImageViewIfNeeded() {
        guard indicatorImage == nil else { return }
        let imageView = UIImageView()
        indicatorImageLabelStackView.addArrangedSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        self.indicatorImage = imageView
    }

    private func buildIndicatorLabelIfNeeded() {
        guard indicatorLabel == nil else { return }
        let label = UILabel()
        indicatorImageLabelStackView.addArrangedSubview(label)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.indicatorLabel = label
    }

    private func setupConstraint(constraint: inout NSLayoutConstraint?, build: (CGFloat) -> NSLayoutConstraint, value: CGFloat, priority: UILayoutPriority = .required) {
        if let constraint {
            constraint.constant = value
            constraint.priority = priority
        } else {
            constraint = build(value)
            constraint?.priority = priority
            constraint?.isActive = true
        }
    }

    private func setupConstraint(constraint: inout NSLayoutConstraint?, build: ((CGFloat) -> NSLayoutConstraint)?, value: CGFloat, priority: UILayoutPriority = .required) {
        guard let build else { return }
        setupConstraint(constraint: &constraint, build: build, value: value, priority: priority)
    }

    private func setupAdditionalInfoView() {
        guard let infoLabelConfig = configuration.infoLabel else { return }
        addSubview(additionalInfoView)
        additionalInfoView.addSubview(offsetLabel)

        let textInsets = infoLabelConfig.textInsets
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false
        offsetLabel.font = infoLabelConfig.font
        offsetLabel.textColor = infoLabelConfig.textColor
        offsetLabel.topAnchor.constraint(equalTo: additionalInfoView.topAnchor, constant: textInsets.top).isActive = true
        offsetLabel.bottomAnchor.constraint(equalTo: additionalInfoView.bottomAnchor, constant: -textInsets.bottom).isActive = true
        offsetLabel.leadingAnchor.constraint(equalTo: additionalInfoView.leadingAnchor, constant: textInsets.left).isActive = true
        offsetLabel.trailingAnchor.constraint(equalTo: additionalInfoView.trailingAnchor, constant: -textInsets.right).isActive = true

        additionalInfoView.translatesAutoresizingMaskIntoConstraints = false
        additionalInfoView.backgroundColor = infoLabelConfig.backgroundColor
        let offsetLabelInitialDistance = infoLabelConfig.animation.animationType == .fadeAndSide ? 0 : infoLabelConfig.distanceToScrollIndicator
        offsetLabelTrailingConstraint = scrollIndicator.leadingAnchor.constraint(equalTo: additionalInfoView.trailingAnchor, constant: offsetLabelInitialDistance)
        offsetLabelTrailingConstraint?.isActive = true
        if let maximumWidth = infoLabelConfig.maximumWidth {
            additionalInfoView.widthAnchor.constraint(lessThanOrEqualToConstant: maximumWidth).isActive = true
        } else if let scrollViewLayoutGuide {
            additionalInfoView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollViewLayoutGuide.leadingAnchor, constant: 8).isActive = true
        }
        additionalInfoView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
        additionalInfoView.layer.maskedCorners = infoLabelConfig.roundedCorners.corners.cornerMask
        additionalInfoView.layer.cornerRadius = cornerRadius(
            from: infoLabelConfig.roundedCorners.radius,
            viewSize: CGSize(
                width: infoLabelConfig.maximumWidth ?? CGFloat.greatestFiniteMagnitude,
                height: infoLabelConfig.font.lineHeight + textInsets.top + textInsets.bottom
            )
        )

        additionalInfoView.alpha = 0
        additionalInfoView.clipsToBounds = true
    }

    private func cornerRadius(from radius: DMScrollBar.Configuration.RoundedCorners.Radius, viewSize: CGSize) -> CGFloat {
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
        guard maxScrollViewOffset > 30 else { return } // Content size should be 30px larger than scrollView.height
        animateScrollBarShow()
        scrollIndicatorTopConstraint?.constant = scrollIndicatorOffsetFromScrollOffset(
            newOffset.y,
            shouldAdjustOverscrollOffset: panGestureRecognizer?.state == .possible && decelerateAnimation == nil
        )
        startHideTimerIfNeeded()
        /// Next code is needed to keep additional info label and scroll bar titles up-to-date during scroll view decelerate
        guard isPanGestureInactive else { return }
        if additionalInfoView.alpha == 1 {
            updateAdditionalInfoViewState(forScrollOffset: newOffset.y, previousOffset: previousOffset?.y)
        }
        if indicatorLabel?.alpha == 1 {
            updateScrollIndicatorText(forScrollOffset: newOffset.y, previousOffset: previousOffset?.y, stateConfig: configuration.indicator.activeState.textConfig)
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
        updateScrollIndicatorText(forScrollOffset: newScrollOffset, previousOffset: previousOffset.y, stateConfig: configuration.indicator.activeState.textConfig)
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
            gestureInteractionEnded(willDecelerate: false)
            generateHapticFeedback()
        case .ended, .failed:
            gestureInteractionEnded(willDecelerate: false)
            generateHapticFeedback()
        default: break
        }
    }

    private func gestureInteractionStarted() {
        let scrollOffset = scrollOffsetFromScrollIndicatorOffset(scrollIndicatorTopConstraint?.constant ?? 0)
        updateAdditionalInfoViewState(forScrollOffset: scrollOffset, previousOffset: nil)
        invalidateHideTimer()
        generateHapticFeedback()
        updateScrollIndicatorText(forScrollOffset: scrollOffset, previousOffset: nil, stateConfig: configuration.indicator.activeState.textConfig)
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

    private func animateIndicatorStateChange(to stateConfig: DMScrollBar.Configuration.Indicator.StateConfig, textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?) {
        animate(duration: configuration.indicator.stateChangeAnimationDuration) { [weak self] in
            self?.setup(stateConfig: stateConfig)
            self?.setupIndicatorImageAndText(image: stateConfig.image, textConfig: textConfig, imageSize: stateConfig.imageSize)
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

        guard configuration.shouldDecelerate else { return }

        decelerateAnimation = TimerAnimation(
            duration: duration,
            animations: { [weak self] _, time in
                guard let self else { return }
                let newY = self.scrollOffsetFromScrollIndicatorOffset(parameters.value(at: time).y)
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
        guard let offsetLabelText = delegate?.infoLabelText(forOffset: scrollViewOffset) else { return animateAdditionalInfoViewHide() }
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

    private func hideIndicatorLabel() {
        indicatorLabel?.alpha = 0
        indicatorLabel?.isHidden = true
    }

    private func showIndicatorLabel() {
        indicatorLabel?.alpha = 1
        indicatorLabel?.isHidden = false
    }

    private func updateScrollIndicatorText(
        forScrollOffset scrollViewOffset: CGFloat,
        previousOffset: CGFloat?,
        stateConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig?
    ) {
        guard let scrollBarLabelText = delegate?.scrollBarText(forOffset: scrollViewOffset), stateConfig != nil else { return hideIndicatorLabel() }
        if scrollBarLabelText == indicatorLabel?.text { return }
        let direction: CATransitionSubtype? = {
            guard let previousOffset else { return nil }
            return scrollViewOffset > previousOffset ? .fromTop : .fromBottom
        }()
        indicatorLabel?.setup(text: scrollBarLabelText, direction: direction)
        indicatorImageLabelStackView.layoutIfNeeded()
        generateHapticFeedback(style: .light)
    }

    private func animateScrollBarShow() {
        guard alpha == 0 else { return }
        setup(stateConfig: configuration.indicator.normalState)
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
        guard let infoLabelConfig = configuration.infoLabel, additionalInfoView.alpha == 0 else { return }
        animate(duration: infoLabelConfig.animation.showDuration) { [weak self] in
            self?.additionalInfoView.alpha = 1
            guard infoLabelConfig.animation.animationType == .fadeAndSide else { return }
            self?.offsetLabelTrailingConstraint?.constant = infoLabelConfig.distanceToScrollIndicator
            self?.layoutIfNeeded()
        }
    }

    private func animateAdditionalInfoViewHide() {
        guard let infoLabelConfig = configuration.infoLabel, additionalInfoView.alpha != 0 else { return }
        animate(duration: infoLabelConfig.animation.hideDuration) { [weak self] in
            self?.additionalInfoView.alpha = 0
            guard infoLabelConfig.animation.animationType == .fadeAndSide else { return }
            self?.offsetLabelTrailingConstraint?.constant = 0
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

private extension DMScrollBar.Configuration.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        switch self {
        case .topLeft: return .layerMinXMinYCorner
        case .bottomLeft: return .layerMinXMaxYCorner
        case .topRight: return .layerMaxXMinYCorner
        case .bottomRight: return .layerMaxXMaxYCorner
        }
    }
}

private extension Sequence where Element == DMScrollBar.Configuration.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        CACornerMask(map(\.cornerMask))
    }
}

private extension DMScrollBar.Configuration.Indicator.StateConfig {
    func applying(scaleFactor: CGFloat) -> DMScrollBar.Configuration.Indicator.StateConfig {
        .init(
            size: CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor),
            backgroundColor: backgroundColor,
            insets: insets,
            image: image,
            imageSize: CGSize(width: imageSize.width * scaleFactor, height: imageSize.height * scaleFactor),
            roundedCorners: roundedCorners
        )
    }
}

private extension DMScrollBar.Configuration.Indicator.ActiveStateConfig {
    var textConfig: DMScrollBar.Configuration.Indicator.ActiveStateConfig.TextConfig? {
        switch self {
        case .custom(_, let textConfig): return textConfig
        default: return nil
        }
    }
}
