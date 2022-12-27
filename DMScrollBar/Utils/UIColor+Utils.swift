import UIKit

extension UIColor {
    private static var backgroundLightGray = UIColor(red: 160/255, green: 160/255, blue: 160/255, alpha: 1)
    private static var backgroundDarkGray = UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 1)

    public static var defaultScrollBarBackground: UIColor {
        UIColor(dynamicProvider: { $0.userInterfaceStyle == .light ? .backgroundLightGray : .backgroundDarkGray })
    }
}
