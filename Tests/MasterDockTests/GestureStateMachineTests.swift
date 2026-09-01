import Foundation
import MasterDockCore

final class GestureStateMachineTests {
    var stateMachine: GestureStateMachine!
    
    func setUp() {
        stateMachine = GestureStateMachine(configuration: .default)
    }
    
    func testInitialStateIsIdle() {
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testLeftEdgeTwoFingerSwipeStartsTracking() {
        var recordedStates: [GestureDockState] = []
        stateMachine.onStateChange = { state in
            recordedStates.append(state)
        }
        
        // Touch down at left edge (x = 0.05) with 2 fingers
        stateMachine.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        
        XCTAssertEqual(recordedStates.count, 1)
        if case .trackingLeftSwipe(let progress, _) = stateMachine.currentState {
            XCTAssertEqual(progress, 0.0, accuracy: 0.01)
        } else {
            XCTFail("Expected trackingLeftSwipe state")
        }
    }
    
    func testLeftEdgeSwipeProgressAndCommitStandardDock() {
        // Touch down at left edge
        stateMachine.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        
        // Move horizontally to x = 0.35 (delta = 0.30)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.35, averageY: 0.5, timestamp: 1.1)
        
        if case .trackingLeftSwipe(let progress, _) = stateMachine.currentState {
            XCTAssertGreaterThan(progress, 0.3)
        } else {
            XCTFail("Expected trackingLeftSwipe")
        }
        
        // Lift fingers -> should commit standard dock
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .dockRevealed(mode: .standardDock))
    }
    
    func testLeftEdgeSwipePastHalfCommitsVoiceMode() {
        // Touch down at left edge
        stateMachine.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        
        // Move horizontally across trackpad past 55%
        stateMachine.processTouches(fingerCount: 2, averageX: 0.55, averageY: 0.5, timestamp: 1.2)
        
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .voiceModeActive)
    }
    
    func testTopEdgeTwoFingerSwipeCommitsVoiceMode() {
        // Touch down at top edge (y = 0.95)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.95, timestamp: 1.0)
        
        // Swipe downward
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.70, timestamp: 1.1)
        
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .voiceModeActive)
    }
    
    func testSingleFingerIgnored() {
        stateMachine.processTouches(fingerCount: 1, averageX: 0.02, averageY: 0.5, timestamp: 1.0)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testLeftEdgeSwipeWhileOpenClosesDock() {
        // Open the dock first
        stateMachine.triggerManual(mode: .standardDock)
        XCTAssertTrue(stateMachine.isDockOpen)
        
        // Touch down at left edge while open
        stateMachine.processTouches(fingerCount: 2, averageX: 0.05, averageY: 0.5, timestamp: 1.0)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.25, averageY: 0.5, timestamp: 1.1)
        stateMachine.finishGesture()
        
        XCTAssertFalse(stateMachine.isDockOpen)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testScrollingWhileOpenLeavesDockOpen() {
        // Open the dock
        stateMachine.triggerManual(mode: .standardDock)
        XCTAssertTrue(stateMachine.isDockOpen)
        
        // Touch down in the middle of trackpad (x = 0.5) to scroll vertically
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.6, timestamp: 1.0)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.4, timestamp: 1.1)
        stateMachine.finishGesture()
        
        // Dock should remain open!
        XCTAssertTrue(stateMachine.isDockOpen)
    }
}
