import Foundation
import CoreGraphics

protocol TimingParameters {
    var duration: TimeInterval { get }
    func value(at time: TimeInterval) -> CGPoint
}
