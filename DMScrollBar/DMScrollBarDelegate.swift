import Foundation

public protocol DMScrollBarDelegate: AnyObject {
    /// This method is triggered every time when scroll bar offset changes while the user is dragging it
    /// - Parameter offset: Scroll view content offset
    /// - Returns: Indicator title to present in info label. If returning nil - the info label will not show
    func indicatorTitle(forOffset offset: CGFloat) -> String?
}
