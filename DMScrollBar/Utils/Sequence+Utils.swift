import UIKit

extension Sequence where Element == DMScrollBar.Configuration.RoundedCorners.Corner {
    var cornerMask: CACornerMask {
        CACornerMask(map(\.cornerMask))
    }
}
