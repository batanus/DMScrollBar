import UIKit
import QuartzCore

extension UILabel {
    func setup(text: String, direction: CATransitionSubtype?) {
        if let direction {
            let animation = CATransition()
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.type = CATransitionType.push
            animation.subtype = direction
            animation.duration = 0.15
            layer.add(animation, forKey: "pushTextChange")
        }
        self.text = text
    }
}
