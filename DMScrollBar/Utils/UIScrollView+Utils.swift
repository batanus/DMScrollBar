import UIKit

private enum AssociatedKeys {
    static var scrollIndicatorStyle = "scrollIndicatorStyle"
    static var scrollBar = "scrollBar"
}

public extension UIScrollView {
    var scrollBar: DMScrollBar? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.scrollBar) as? DMScrollBar
        } set {
            objc_setAssociatedObject(self, &AssociatedKeys.scrollBar, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }

    func configureScrollBar(with configuration: DMScrollBar.Configuration = .default, delegate: DMScrollBarDelegate? = nil) {
        scrollBar?.removeFromSuperview()
        let scrollBar = DMScrollBar(scrollView: self, delegate: delegate, configuration: configuration)
        self.scrollBar = scrollBar
    }
}
