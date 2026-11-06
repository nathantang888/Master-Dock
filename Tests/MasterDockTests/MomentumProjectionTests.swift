import Foundation
import MasterDockCore

/// The dock decides open or close from where the swipe is heading (Apple's momentum projection),
/// not only from where the fingers lifted.
public struct MomentumProjectionTests {
    public init() {}
    
    public func testProjectionMatchesAppleFormula() {
        // 1000 units/s with deceleration 0.998 travels 499 units before resting.
        XCTAssertEqual(GestureStateMachine.project(velocity: 1000), 499.0, accuracy: 0.001)
        XCTAssertEqual(GestureStateMachine.project(velocity: -1000), -499.0, accuracy: 0.001)
    }
    
    public func testQuickShortFlickOpensDock() {
        let g = GestureStateMachine(configuration: .default)
        g.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        g.processTouches(fingerCount: 2, averageX: 0.10, averageY: 0.5, timestamp: 1.04)
        g.finishGesture()
        XCTAssertEqual(g.currentState, .dockRevealed(mode: .standardDock))
    }
    
    public func testSlowTinyNudgeDoesNotOpen() {
        let g = GestureStateMachine(configuration: .default)
        g.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        g.processTouches(fingerCount: 2, averageX: 0.09, averageY: 0.5, timestamp: 2.0)
        g.finishGesture()
        XCTAssertFalse(g.isDockOpen)
        XCTAssertEqual(g.currentState, .idle)
    }
    
    public func testPullingBackCancelsEvenAfterTravellingFar() {
        let g = GestureStateMachine(configuration: .default)
        g.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        g.processTouches(fingerCount: 2, averageX: 0.40, averageY: 0.5, timestamp: 1.5)
        g.processTouches(fingerCount: 2, averageX: 0.30, averageY: 0.5, timestamp: 1.55)
        g.finishGesture()
        XCTAssertFalse(g.isDockOpen)
        XCTAssertEqual(g.currentState, .idle)
    }
}
