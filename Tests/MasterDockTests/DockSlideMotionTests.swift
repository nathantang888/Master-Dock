import Foundation
import MasterDockCore

public struct DockSlideMotionTests {
    public init() {}

    private func runSpring(_ motion: inout DockSlideMotion, target: Double, response: Double, damping: Double, hz: Double, maxSeconds: Double) -> (settled: Bool, seconds: Double, peak: Double) {
        let dt = 1.0 / hz
        var elapsed = 0.0
        var peak = motion.position
        while elapsed < maxSeconds {
            let settled = motion.stepSpring(target: target, dt: dt, response: response, dampingRatio: damping)
            elapsed += dt
            peak = max(peak, motion.position)
            if settled { return (true, elapsed, peak) }
        }
        return (false, elapsed, peak)
    }

    public func testOpenSpringSettlesQuickly() {
        var motion = DockSlideMotion()
        let result = runSpring(&motion, target: 340, response: 0.42, damping: 0.86, hz: 120, maxSeconds: 2)
        XCTAssertTrue(result.settled, "spring should settle")
        XCTAssertTrue(result.seconds < 1.0, "open animation took \(result.seconds)s")
        XCTAssertEqual(motion.position, 340.0, accuracy: 0.001)
        XCTAssertEqual(motion.velocity, 0.0, accuracy: 0.001)
    }

    public func testCriticallyDampedCloseNeverOvershoots() {
        var motion = DockSlideMotion(position: 340)
        let dt = 1.0 / 120.0
        var lowest = motion.position
        for _ in 0..<240 {
            motion.stepSpring(target: 0, dt: dt, response: 0.30, dampingRatio: 1.0)
            lowest = min(lowest, motion.position)
        }
        XCTAssertTrue(lowest >= -0.5, "close spring went past hidden: \(lowest)")
        XCTAssertEqual(motion.position, 0.0, accuracy: 0.001)
    }

    public func testSpringBehavesTheSameAt60And120Hz() {
        var at60 = DockSlideMotion()
        var at120 = DockSlideMotion()
        for _ in 0..<12 { at60.stepSpring(target: 340, dt: 1.0 / 60.0, response: 0.42, dampingRatio: 0.86) }
        for _ in 0..<24 { at120.stepSpring(target: 340, dt: 1.0 / 120.0, response: 0.42, dampingRatio: 0.86) }
        XCTAssertEqual(at60.position, at120.position, accuracy: 2.0)
    }

    public func testReleaseVelocityCarriesIntoSpring() {
        var still = DockSlideMotion(position: 100, velocity: 0)
        var flung = DockSlideMotion(position: 100, velocity: 2000)
        still.stepSpring(target: 340, dt: 1.0 / 120.0, response: 0.42, dampingRatio: 0.86)
        flung.stepSpring(target: 340, dt: 1.0 / 120.0, response: 0.42, dampingRatio: 0.86)
        XCTAssertGreaterThan(flung.position, still.position)
    }

    public func testFollowTracksFingerAndIgnoresStalls() {
        var motion = DockSlideMotion()
        for _ in 0..<60 { motion.follow(target: 200, dt: 1.0 / 120.0) }
        XCTAssertEqual(motion.position, 200.0, accuracy: 1.0)

        // A long stalled frame must not teleport or fling the dock.
        var stalled = DockSlideMotion()
        stalled.follow(target: 300, dt: 2.0)
        XCTAssertTrue(stalled.position < 300, "a stalled frame should be clamped")
        XCTAssertTrue(stalled.position > 0)
    }
}
