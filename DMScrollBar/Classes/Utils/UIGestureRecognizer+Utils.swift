import UIKit

extension UIGestureRecognizer {
    func cancel() {
        isEnabled = false
        isEnabled = true
    }
}

extension UIGestureRecognizer.State {
    var isInactive: Bool {
        switch self {
        case .possible, .ended, .cancelled, .failed: return true
        case .began, .changed: return false
        @unknown default: return true
        }
    }
}
