import UIKit

private enum AssociatedKeys {
    static var scrollIndicatorStyle = "scrollIndicatorStyle"
    static var scrollBar = "scrollBar"
}

public extension UIScrollView {
    var scrollBar: DMScrollBar? {
        get {
            withUnsafePointer(to: &AssociatedKeys.scrollBar) {
                objc_getAssociatedObject(self, $0) as? DMScrollBar
            }
        } set {
            withUnsafePointer(to: &AssociatedKeys.scrollBar) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }

    func configureScrollBar(with configuration: DMScrollBar.Configuration = .default, delegate: DMScrollBarDelegate? = nil) {
        scrollBar?.removeFromSuperview()
        let scrollBar = DMScrollBar(scrollView: self, delegate: delegate, configuration: configuration)
        self.scrollBar = scrollBar
    }
}
