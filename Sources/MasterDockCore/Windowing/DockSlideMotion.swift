import Foundation

/// Pure motion math for sliding the dock in and out.
///
/// `position` is how many points of the dock are revealed (0 = hidden, dock width = fully shown).
/// It has no AppKit dependencies so it can be unit tested.
public struct DockSlideMotion: Equatable, Sendable {
    /// Revealed distance in points.
    public var position: Double
    /// Current speed in points per second (positive = opening).
    public var velocity: Double

    public init(position: Double = 0, velocity: Double = 0) {
        self.position = position
        self.velocity = velocity
    }

    /// Eases toward the finger position. Frame rate independent, and filters out trackpad jitter
    /// while still feeling attached to the finger.
    public mutating func follow(target: Double, dt: Double, sharpness: Double = 30) {
        let dt = Self.clampedStep(dt)
        guard dt > 0 else { return }

        let previous = position
        let blend = 1 - exp(-sharpness * dt)
        position += (target - position) * blend

        // Light low-pass on velocity so the speed handed to the release spring is not noisy.
        let instantVelocity = (position - previous) / dt
        velocity += (instantVelocity - velocity) * min(1, dt * 25)
    }

    /// Advances a damped spring toward `target`, keeping whatever velocity the dock already has.
    /// - Parameters:
    ///   - response: Roughly how long one oscillation takes, in seconds. Smaller is snappier.
    ///   - dampingRatio: 1.0 never overshoots, below 1.0 adds a little bounce.
    /// - Returns: `true` once the spring has settled on the target.
    @discardableResult
    public mutating func stepSpring(target: Double, dt: Double, response: Double, dampingRatio: Double) -> Bool {
        let dt = Self.clampedStep(dt)
        guard dt > 0 else { return isSettled(at: target) }

        let omega = 2 * Double.pi / max(response, 0.01)
        let stiffness = omega * omega
        let damping = 2 * dampingRatio * omega

        // Small fixed substeps keep the integration stable on 60 Hz and 120 Hz displays alike.
        let substeps = max(1, Int((dt / Self.maxSubstep).rounded(.up)))
        let h = dt / Double(substeps)
        for _ in 0..<substeps {
            let acceleration = -stiffness * (position - target) - damping * velocity
            velocity += acceleration * h
            position += velocity * h
        }

        if isSettled(at: target) {
            position = target
            velocity = 0
            return true
        }
        return false
    }

    public func isSettled(at target: Double) -> Bool {
        return abs(position - target) < 0.5 && abs(velocity) < 8
    }

    private static let maxSubstep = 1.0 / 240.0

    /// Ignores huge gaps (app was stalled, display slept) so one late frame cannot fling the dock.
    private static func clampedStep(_ dt: Double) -> Double {
        return max(0, min(dt, 1.0 / 30.0))
    }
}
