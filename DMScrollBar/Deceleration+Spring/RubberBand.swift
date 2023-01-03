import Foundation
import CoreGraphics

func rubberBandClamp(_ x: CGFloat, coeff: CGFloat, dim: CGFloat) -> CGFloat {
    return (1.0 - (1.0 / (x * coeff / dim + 1.0))) * dim
}

func rubberBandClamp(_ x: CGFloat, coeff: CGFloat, dim: CGFloat, limits: ClosedRange<CGFloat>) -> CGFloat {
    let clampedX = x.clamped(to: limits)
    let diff = abs(x - clampedX)
    let sign: CGFloat = clampedX > x ? -1 : 1
    return clampedX + sign * rubberBandClamp(diff, coeff: coeff, dim: dim)
}

struct RubberBand {
    static let defaultCoefficient = 0.55
    var coeff: CGFloat
    var dims: CGSize
    var bounds: CGRect

    init(coeff: CGFloat = defaultCoefficient, dims: CGSize, bounds: CGRect) {
        self.coeff = coeff
        self.dims = dims
        self.bounds = bounds
    }

    func clamp(_ point: CGPoint) -> CGPoint {
        let x = rubberBandClamp(point.x, coeff: coeff, dim: dims.width, limits: bounds.minX...bounds.maxX)
        let y = rubberBandClamp(point.y, coeff: coeff, dim: dims.height, limits: bounds.minY...bounds.maxY)
        return CGPoint(x: x, y: y)
    }
}
