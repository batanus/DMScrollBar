import Foundation
import QuartzCore

final class TimerAnimation {
    typealias Animations = (_ progress: Double, _ time: TimeInterval) -> Void
    typealias Completion = (_ finished: Bool) -> Void

    private weak var displayLink: CADisplayLink?
    private let duration: TimeInterval
    private let animations: Animations
    private let completion: Completion?
    private let firstFrameTimestamp: CFTimeInterval
    private var running = true

    deinit {
        invalidate()
    }
    
    init(duration: TimeInterval, animations: @escaping Animations, completion: Completion? = nil) {
        self.duration = duration
        self.animations = animations
        self.completion = completion
        self.firstFrameTimestamp = CACurrentMediaTime()
        let displayLink = CADisplayLink(target: self, selector: #selector(handleFrame(_:)))
        displayLink.add(to: .main, forMode: RunLoopMode.commonModes)
        self.displayLink = displayLink
    }
    
    func invalidate() {
        guard running else { return }
        running = false
        completion?(false)
        displayLink?.invalidate()
    }

    @objc private func handleFrame(_ displayLink: CADisplayLink) {
        guard running else { return }
        let elapsed = CACurrentMediaTime() - firstFrameTimestamp
        if elapsed >= duration {
            animations(1, duration)
            running = false
            completion?(true)
            displayLink.invalidate()
        } else {
            animations(elapsed / duration, elapsed)
        }
    }
}
