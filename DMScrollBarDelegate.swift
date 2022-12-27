import Foundation

public protocol DMScrollBarDelegate: AnyObject {
    func indicatorTitle(forOffset offset: CGFloat) -> String?
}
