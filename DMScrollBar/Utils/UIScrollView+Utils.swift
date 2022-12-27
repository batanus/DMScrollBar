import UIKit

private enum AssociatedKeys {
    static var scrollIndicatorStyle = "scrollIndicatorStyle"
    static var scrollBar = "scrollBar"
}

public enum ScrollIndicatorStyle {
    case `default`
    case custom(DMScrollBar.Configuration = .default, DMScrollBarDelegate? = nil)
}

public extension UIScrollView {
    var scrollBar: DMScrollBar? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.scrollBar) as? DMScrollBar
        } set {
            objc_setAssociatedObject(self, &AssociatedKeys.scrollBar, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    var scrollIndicatorStyle: ScrollIndicatorStyle {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.scrollIndicatorStyle) as? ScrollIndicatorStyle ?? .default
        } set {
            objc_setAssociatedObject(self, &AssociatedKeys.scrollIndicatorStyle, newValue, .OBJC_ASSOCIATION_RETAIN)
            switch newValue {
            case .default:
                scrollBar?.removeFromSuperview()
                scrollBar = nil
            case .custom(let configuration, let delegate):
                scrollBar = DMScrollBar(scrollView: self, delegate: delegate, configuration: configuration)
            }
        }
    }
}
