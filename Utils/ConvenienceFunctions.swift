import Foundation

func interval<T: Comparable>(_ minimum: T, _ num: T, _ maximum: T) -> T {
    return min(maximum, max(minimum, num))
}
