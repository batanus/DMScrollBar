import UIKit

extension UIView {
   var frameInWindow: CGRect {
       convert(bounds, to: nil)
   }
}
