import Foundation
import CoreGraphics

struct DecelerationTimingParameters {
    var initialValue: CGPoint
    var initialVelocity: CGPoint
    var decelerationRate: CGFloat
    var threshold: CGFloat
}

extension DecelerationTimingParameters {
    var destination: CGPoint {
        let dCoeff = 1000 * log(decelerationRate)
        return initialValue - initialVelocity / dCoeff
    }

    var duration: TimeInterval {
        guard initialVelocity.length > 0 else { return 0 }
        let dCoeff = 1000 * log(decelerationRate)
        return TimeInterval(log(-dCoeff * threshold / initialVelocity.length) / dCoeff)
    }

    func value(at time: TimeInterval) -> CGPoint {
        let dCoeff = 1000 * log(decelerationRate)
        return initialValue + (pow(decelerationRate, CGFloat(1000 * time)) - 1) / dCoeff * initialVelocity
    }

    func duration(to value: CGPoint) -> TimeInterval? {
        guard value.distance(toSegment: (initialValue, destination)) < threshold else { return nil }
        let dCoeff = 1000 * log(decelerationRate)
        return TimeInterval(log(1.0 + dCoeff * (value - initialValue).length / initialVelocity.length) / dCoeff)
    }

    func velocity(at time: TimeInterval) -> CGPoint {
        return initialVelocity * pow(decelerationRate, CGFloat(1000 * time))
    }
}
