import UIKit
import QuartzCore

extension UILabel {
    func setup(text: String, direction: CATransitionSubtype?, duration: TimeInterval) {
        if let direction {
            let animation = CATransition()
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.type = CATransitionType.push
            animation.subtype = direction
            animation.duration = duration
            layer.add(animation, forKey: "pushTextChange")
        }
        self.text = text
    }
}
