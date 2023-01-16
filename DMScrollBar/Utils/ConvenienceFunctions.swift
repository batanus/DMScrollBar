import Foundation

func interval<T: Comparable>(_ minimum: T, _ num: T, _ maximum: T) -> T {
    return min(maximum, max(minimum, num))
}

func cornerRadius(from radius: DMScrollBar.Configuration.RoundedCorners.Radius, viewSize: CGSize) -> CGFloat {
    switch radius {
    case .notRounded: return 0
    case .rounded: return min(viewSize.height, viewSize.width) / 2
    case .custom(let radius): return radius
    }
}

func setupConstraint(constraint: inout NSLayoutConstraint?, build: (CGFloat) -> NSLayoutConstraint, value: CGFloat, priority: UILayoutPriority = .required) {
    if let constraint {
        constraint.constant = value
        constraint.priority = priority
    } else {
        constraint = build(value)
        constraint?.priority = priority
        constraint?.isActive = true
    }
}

func setupConstraint(constraint: inout NSLayoutConstraint?, build: ((CGFloat) -> NSLayoutConstraint)?, value: CGFloat, priority: UILayoutPriority = .required) {
    guard let build else { return }
    setupConstraint(constraint: &constraint, build: build, value: value, priority: priority)
}

func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
