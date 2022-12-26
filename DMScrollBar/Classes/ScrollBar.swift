import UIKit
import Combine

public protocol ScrollBarDelegate: AnyObject {
    func indicatorTitle(forOffset offset: CGFloat) -> String?
}

public class ScrollBar: UIView {
    public struct Configuration: Equatable {
        public struct Indicator: Equatable {
            public let size: CGSize
            public let backgroundColor: UIColor
            public let insets: UIEdgeInsets
            public let insetsFollowsSafeArea: Bool
            public let image: UIImage?
            public let imageSize: CGSize

            public init(
                size: CGSize = CGSize(width: 34, height: 34),
                backgroundColor: UIColor = UIColor.systemGray,
                insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0),
                insetsFollowsSafeArea: Bool = true,
                image: UIImage? = UIImage(systemName: "calendar.circle")?.withRenderingMode(.alwaysOriginal).withTintColor(UIColor.systemBackground),
                imageSize: CGSize = CGSize(width: 20, height: 20)
            ) {
                self.size = size
                self.backgroundColor = backgroundColor
                self.insets = insets
                self.insetsFollowsSafeArea = insetsFollowsSafeArea
                self.image = image
                self.imageSize = imageSize
            }

            public static let `default` = Indicator()
        }

        public struct InfoLabel: Equatable {
            public let font: UIFont
            public let textColor: UIColor
            public let distanceToScrollIndicator: CGFloat
            public let backgroundColor: UIColor
            public let textInsets: UIEdgeInsets

            public init(
                font: UIFont = UIFont.systemFont(ofSize: 13),
                textColor: UIColor = UIColor.systemBackground,
                distanceToScrollIndicator: CGFloat = 40,
                backgroundColor: UIColor = UIColor.systemGray,
                textInsets: UIEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            ) {
                self.font = font
                self.textColor = textColor
                self.distanceToScrollIndicator = distanceToScrollIndicator
                self.backgroundColor = backgroundColor
                self.textInsets = textInsets
            }

            public static let `default` = InfoLabel()
        }

        public let isAlwaysVisible: Bool
        public let hideTimeInterval: TimeInterval
        public let indicator: Indicator
        public let infoLabel: InfoLabel

        public init(
            isAlwaysVisible: Bool = true,
            hideTimeInterval: TimeInterval = 2,
            indicator: Indicator = .default,
            infoLabel: InfoLabel = .default
        ) {
            self.isAlwaysVisible = isAlwaysVisible
            self.hideTimeInterval = hideTimeInterval
            self.indicator = indicator
            self.infoLabel = infoLabel
        }

        public static let `default` = Configuration()
    }

    // MARK: - Properties

    private weak var scrollView: UIScrollView?
    private weak var delegate: ScrollBarDelegate?
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
        delegate: ScrollBarDelegate? = nil,
        configuration: Configuration = .default
    ) {
        self.scrollView = scrollView
        self.configuration = configuration
        self.delegate = delegate
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
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

    private func setupScrollIndicator() {
        addSubview(scrollIndicator)
        scrollIndicator.translatesAutoresizingMaskIntoConstraints = false
        scrollIndicator.backgroundColor = configuration.indicator.backgroundColor
        scrollIndicatorTopConstraint = scrollIndicator.topAnchor.constraint(equalTo: topAnchor, constant: configuration.indicator.insets.top)
        scrollIndicatorTopConstraint?.isActive = true
        scrollIndicator.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        scrollIndicator.widthAnchor.constraint(equalToConstant: configuration.indicator.size.width).isActive = true
        scrollIndicator.heightAnchor.constraint(equalToConstant: configuration.indicator.size.height).isActive = true
        scrollIndicator.layer.cornerRadius = configuration.indicator.size.height / 2
        scrollIndicator.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
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
        let infoViewHeight = configuration.infoLabel.font.lineHeight + textInsets.top + textInsets.bottom
        additionalInfoView.layer.cornerRadius = infoViewHeight / 2

        additionalInfoView.alpha = 0
    }

    // MARK: - Scroll view observation

    private func observeScrollViewProperties() {
        scrollView?
            .publisher(for: \.contentOffset)
            .dropFirst()
            .removeDuplicates()
            .withPrevious()
            .sink { [weak self] in self?.handleScrollViewOffsetChange(previousOffset: $0, newOffset: $1) }
            .store(in: &cancellables)
        scrollView?
            .panGestureRecognizer
            .publisher(for: \.state)
            .dropFirst()
            .removeDuplicates()
            .sink{ [weak self] in self?.handleScrollViewGestureState($0) }
            .store(in: &cancellables)
    }

    private func handleScrollViewOffsetChange(previousOffset: CGPoint?, newOffset: CGPoint) {
        animateScrollBarShow()
        scrollIndicatorTopConstraint?.constant = scrollIndicatorOffsetFromScrollOffset(newOffset.y)
        startHideTimerIfNeeded()
        guard additionalInfoView.alpha == 1 && isPanGestureInactive else { return }
        animateAndSetupAdditionalInfoViewShowIfNeeded(forScrollOffset: newOffset.y, previousOffset: previousOffset?.y)
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
        animateAndSetupAdditionalInfoViewShowIfNeeded(forScrollOffset: scrollOffset, previousOffset: nil)
    }

    private func handlePanGestureChanged(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView else { return }
        let offset = recognizer.translation(in: scrollView)
        let newScrollOffset = scrollOffsetFromScrollIndicatorOffset((scrollIndicatorOffsetOnGestureStart ?? 0) + offset.y)
        let previousOffset = scrollView.contentOffset
        scrollView.setContentOffset(CGPoint(x: 0, y: newScrollOffset), animated: false)
        animateAndSetupAdditionalInfoViewShowIfNeeded(forScrollOffset: newScrollOffset, previousOffset: previousOffset.y)
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
            animateAndSetupAdditionalInfoViewShowIfNeeded(forScrollOffset: scrollOffset, previousOffset: nil)
            recognizer.cancel()
        default: break
        }
    }

    private func animateAndSetupAdditionalInfoViewShowIfNeeded(forScrollOffset scrollViewOffset: CGFloat, previousOffset: CGFloat?) {
        guard let offsetLabelText = delegate?.indicatorTitle(forOffset: scrollViewOffset) else { return }
        animateAdditionalInfoViewShow()
        if offsetLabelText == offsetLabel.text { return }
        let direction: String = {
            guard let previousOffset else { return kCATransitionFromTop }
            return scrollViewOffset > previousOffset ? kCATransitionFromTop : kCATransitionFromBottom
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
            decelerationRate: UIScrollViewDecelerationRateNormal,
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
        return scrollView.contentInset.top
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
            height: maxScrollIndicatorOffset
        )
    }

    private var scrollViewOffsetBounds: CGRect {
        CGRect(
            x: 0,
            y: minScrollViewOffset,
            width: CGFLOAT_MIN,
            height: maxScrollViewOffset
        )
    }

    private var scrollIndicatorTopOffset: CGPoint {
        CGPoint(x: 0, y: scrollIndicatorTopConstraint?.constant ?? 0)
    }

    private func scrollOffsetFromScrollIndicatorOffset(_ offset: CGFloat) -> CGFloat {
        let scrollIndicatorOffsetPercent = (offset - minScrollIndicatorOffset) / (maxScrollIndicatorOffset - minScrollIndicatorOffset)
        let sanitizedScrollIndicatorOffsetPercent = scrollIndicatorOffsetPercent
        let scrollOffset = maxScrollViewOffset * sanitizedScrollIndicatorOffsetPercent

        return scrollOffset
    }

    private func scrollIndicatorOffsetFromScrollOffset(_ offset: CGFloat) -> CGFloat {
        let scrollOffsetPercent = offset / maxScrollViewOffset
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

extension ScrollBar: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return gestureRecognizer == panGestureRecognizer && otherGestureRecognizer == longPressGestureRecognizer
    }
}
