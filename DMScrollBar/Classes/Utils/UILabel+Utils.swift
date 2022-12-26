import UIKit
import QuartzCore

extension UILabel {
    func setup(text: String, direction: String?) {
        if let direction {
            let animation = CATransition()
            animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            animation.type = kCATransitionPush
            animation.subtype = direction
            animation.duration = 0.15
            layer.add(animation, forKey: "pushTextChange")
        }
        self.text = text
    }
}
