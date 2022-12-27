import UIKit
import Combine

public class DMScrollBar: UIView {

    // MARK: - Properties

    private weak var scrollView: UIScrollView?
    private weak var delegate: DMScrollBarDelegate?
    private let configuration: Configuration
    private let scrollIndicator = UIView()
    private let additionalInfoView = UIView()
    private let offsetLabel = UILabel()

    private var scrollIndicatorTopConstraint: NSLayoutConstraint?
    private var cancellables = Set<AnyCancellable>()
    private var hideTimer: Timer?
    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    private var decelerateAnimation: TimerAnimation?

    private var scrollIndicatorOffsetOnGestureStart: CGFloat?
    private var wasHapticGeneratedOnLongPress = false

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
        guard let scrollView else { return }
        scrollView.addSubview(self)
        let layoutGuide = configuration.indicator.insetsFollowsSafeArea ?
            scrollView.safeAreaLayoutGuide :
            scrollView.frameLayoutGuide
        trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor).isActive = true
        topAnchor.constraint(equalTo: layoutGuide.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor).isActive = true
        widthAnchor.constraint(equalToConstant: configuration.indicator.size.width).isActive = true
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
        scrollIndicator.backgroundColor = configuration.indicator.backgroundColor
        scrollIndicatorTopConstraint = scrollIndicator.topAnchor.constraint(equalTo: topAnchor, constant: configuration.indicator.insets.top)
        scrollIndicatorTopConstraint?.isActive = true
        scrollIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: configuration.indicator.insets.right).isActive = true
        scrollIndicator.widthAnchor.constraint(equalToConstant: configuration.indicator.size.width).isActive = true
        scrollIndicator.heightAnchor.constraint(equalToConstant: configuration.indicator.size.height).isActive = true
        scrollIndicator.layer.maskedCorners = configuration.indicator.rounderCorners.corners.map(\.cornerMask).cornerMask
        scrollIndicator.layer.cornerRadius = cornerRadius(
            from: configuration.indicator.rounderCorners.radius,
            viewHeight: configuration.indicator.size.height
        )
        guard let image = configuration.indicator.image else { return }
        let imageView = UIImageView()
        scrollIndicator.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        imageView.centerXAnchor.constraint(equalTo: scrollIndicator.centerXAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: configuration.indicator.imageSize.width).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: configuration.indicator.imageSize.height).isActive = true
    }

    private func setupAdditionalInfoView() {
        addSubview(additionalInfoView)
        additionalInfoView.addSubview(offsetLabel)

        let textInsets = configuration.infoLabel.textInsets
        let distanceToScrollIndicator = configuration.infoLabel.distanceToScrollIndicator
        offsetLabel.translatesAutoresizingMaskIntoConstraints = false
        offsetLabel.font = configuration.infoLabel.font
        offsetLabel.textColor = configuration.infoLabel.textColor
        offsetLabel.topAnchor.constraint(equalTo: additionalInfoView.topAnchor, constant: textInsets.top).isActive = true
        offsetLabel.bottomAnchor.constraint(equalTo: additionalInfoView.bottomAnchor, constant: -textInsets.bottom).isActive = true
        offsetLabel.leadingAnchor.constraint(equalTo: additionalInfoView.leadingAnchor, constant: textInsets.left).isActive = true
        offsetLabel.trailingAnchor.constraint(equalTo: additionalInfoView.trailingAnchor, constant: -textInsets.right).isActive = true

        additionalInfoView.translatesAutoresizingMaskIntoConstraints = false
        additionalInfoView.backgroundColor = configuration.infoLabel.backgroundColor
        scrollIndicator.leadingAnchor.constraint(equalTo: additionalInfoView.trailingAnchor, constant: distanceToScrollIndicator).isActive = true
        additionalInfoView.centerYAnchor.constraint(equalTo: scrollIndicator.centerYAnchor).isActive = true
        additionalInfoView.layer.maskedCorners = configuration.infoLabel.rounderCorners.corners.map(\.cornerMask).cornerMask
        additionalInfoView.layer.cornerRadius = cornerRadius(
            from: configuration.indicator.rounderCorners.radius,
            viewHeight: configuration.infoLabel.font.lineHeight + textInsets.top + textInsets.bottom
        )

        additionalInfoView.alpha = 0
    }

    private func cornerRadius(from radius: DMScrollBar.RoundedCorners.Radius, viewHeight: CGFloat) -> CGFloat {
        switch radius {
        case .notRounded: return 0
        case .rounded: return viewHeight / 2
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
        animateScrollBarShow()
        scrollIndicatorTopConstraint?.constant = scrollIndicatorOffsetFromScrollOffset(newOffset.y)
        startHideTimerIfNeeded()
        /// Next code is needed to keep additional info label title up-to-date during scroll view decelerate
        guard additionalInfoView.alpha == 1 && isPanGestureInactive else { return }
        updateAdditionalInfoViewState(forScrollOffset: newOffset.y, previousOffset: previousOffset?.y)
    }

    private func handleScrollViewGestureState(_ state: UIGestureRecognizer.State) {
        cancelDecelerateAnimation()
        animateAdditionalInfoViewHide()
    }

    // MARK: - Gesture Recognizers

    private func addGestureRecognizers() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panGestureRecognizer.delegate = self
        scrollIndicator.addGestureRecognizer(panGestureRecognizer)
        self.panGestureRecognizer = panGestureRecognizer
        scrollView?.panGestureRecognizer.require(toFail: panGestureRecognizer)

        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
        longPressGestureRecognizer.minimumPressDuration = 0.2
        scrollIndicator.addGestureRecognizer(longPressGestureRecognizer)
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
        generateHapticFeedbackOnPanStartIfNeeded()
        cancelDecelerateAnimation()
        scrollIndicatorOffsetOnGestureStart = scrollIndicatorTopConstraint?.constant
        invalidateHideTimer()
        let scrollOffset = scrollOffsetFromScrollIndicatorOffset(scrollIndicatorTopConstraint?.constant ?? 0)
        updateAdditionalInfoViewState(forScrollOffset: scrollOffset, previousOffset: nil)
    }

    private func handlePanGestureChanged(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        let offset = recognizer.translation(in: scrollView)
        let newScrollOffset = scrollOffsetFromScrollIndicatorOffset((scrollIndicatorOffsetOnGestureStart ?? 0) + offset.y)
        let previousOffset = scrollView.contentOffset
        scrollView.setContentOffset(CGPoint(x: 0, y: newScrollOffset), animated: false)
        updateAdditionalInfoViewState(forScrollOffset: newScrollOffset, previousOffset: previousOffset.y)
    }

    private func handlePanGestureEnded(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        scrollIndicatorOffsetOnGestureStart = nil
        startHideTimerIfNeeded()
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
            wasHapticGeneratedOnLongPress = true
            generateHapticFeedback()
            let scrollOffset = scrollOffsetFromScrollIndicatorOffset(scrollIndicatorTopConstraint?.constant ?? 0)
            updateAdditionalInfoViewState(forScrollOffset: scrollOffset, previousOffset: nil)
            recognizer.cancel()
        default: break
        }
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
        generateHapticFeedback()
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
                guard finished && intersection != nil else { return }
                let velocity = parameters.velocity(at: duration)
                self?.bounce(withVelocity: velocity)
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

    private func cancelDecelerateAnimation() {
        decelerateAnimation?.invalidate()
        decelerateAnimation = nil
    }

    // MARK: - Calculations

    private var minScrollIndicatorOffset: CGFloat {
        return configuration.indicator.insets.top
    }

    private var maxScrollIndicatorOffset: CGFloat {
        return frame.height - scrollIndicator.frame.height - configuration.indicator.insets.bottom
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
            width: CGFLOAT_MIN,
            height: maxScrollIndicatorOffset - minScrollIndicatorOffset
        )
    }

    private var scrollViewOffsetBounds: CGRect {
        CGRect(
            x: 0,
            y: minScrollViewOffset,
            width: CGFLOAT_MIN,
            height: maxScrollViewOffset - minScrollViewOffset
        )
    }

    private var scrollIndicatorTopOffset: CGPoint {
        CGPoint(x: 0, y: scrollIndicatorTopConstraint?.constant ?? 0)
    }

    private func scrollOffsetFromScrollIndicatorOffset(_ offset: CGFloat) -> CGFloat {
        let scrollIndicatorOffsetPercent = (offset - minScrollIndicatorOffset) / (maxScrollIndicatorOffset - minScrollIndicatorOffset)
        let scrollOffset = scrollIndicatorOffsetPercent * (maxScrollViewOffset - minScrollViewOffset) + minScrollViewOffset

        return scrollOffset
    }

    private func scrollIndicatorOffsetFromScrollOffset(_ offset: CGFloat) -> CGFloat {
        let scrollOffsetPercent = (offset - minScrollViewOffset) / (maxScrollViewOffset - minScrollViewOffset)
        let scrollIndicatorOffset = scrollOffsetPercent * (maxScrollIndicatorOffset - minScrollIndicatorOffset) + minScrollIndicatorOffset

        return scrollIndicatorOffset
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

    private func animateScrollBarShow() {
        guard alpha == 0 else { return }
        animate(duration: 0.1) { [weak self] in
            self?.alpha = 1
        }
    }

    private func animateScrollBarHide() {
        animate(duration: 0.3) { [weak self] in
            guard let self else { return }
            if !self.configuration.isAlwaysVisible {
                self.alpha = 0
            }
            self.additionalInfoView.alpha = 0
        }
    }

    private func animateAdditionalInfoViewHide() {
        if additionalInfoView.alpha == 0 { return }
        animate(duration: 0.3) { [weak self] in
            self?.additionalInfoView.alpha = 0
        }
    }

    private func animateAdditionalInfoViewShow() {
        guard additionalInfoView.alpha == 0 else { return }
        animate(duration: 0.1) { [weak self] in
            self?.additionalInfoView.alpha = 1
        }
    }

    private func animate(duration: CGFloat, animation: @escaping () -> Void) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            animations: animation
        )
    }

    private func generateHapticFeedbackOnPanStartIfNeeded() {
        if wasHapticGeneratedOnLongPress {
            wasHapticGeneratedOnLongPress = false
        } else {
            generateHapticFeedback()
        }
    }

    private func generateHapticFeedback() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - UIGestureRecognizerDelegateg

extension DMScrollBar: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == longPressGestureRecognizer
    }
}

private extension DMScrollBar.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        switch self {
        case .leftTop: return .layerMinXMinYCorner
        case .leftBottom: return .layerMinXMaxYCorner
        case .rightTop: return .layerMaxXMinYCorner
        case .rightBottom: return .layerMaxXMaxYCorner
        }
    }
}

private extension [CACornerMask] {
    var cornerMask: CACornerMask {
        reduce(CACornerMask()) { $0.union(CACornerMask(rawValue: $1.rawValue)) }
    }
}
