import Foundation
import SwiftUI
import MasterDockUI

public struct ScrollEdgeFadeTests {
    public init() {}
    
    public func testInitialRestingStateHasZeroFade() {
        // When content fits without overflow
        let state = ScrollEdgeCalculator.calculateFade(offsetY: 0, distFromBottom: 0, fadeThreshold: 20)
        XCTAssertEqual(state.topFadeProgress, 0.0)
        XCTAssertEqual(state.bottomFadeProgress, 0.0)
    }
    
    public func testScrollingDownStartsFading() {
        // When starting to scroll down (10pt of 20pt threshold), top starts fading
        let state = ScrollEdgeCalculator.calculateFade(offsetY: 10, distFromBottom: 300, fadeThreshold: 20)
        XCTAssertEqual(state.topFadeProgress, 0.5)
        XCTAssertEqual(state.bottomFadeProgress, 1.0)
    }
    
    public func testFullyScrolledPastThreshold() {
        // When scrolled well into content
        let state = ScrollEdgeCalculator.calculateFade(offsetY: 50, distFromBottom: 200, fadeThreshold: 20)
        XCTAssertEqual(state.topFadeProgress, 1.0)
        XCTAssertEqual(state.bottomFadeProgress, 1.0)
    }
    
    public func testReachingBottomClearsBottomFade() {
        // When at the very bottom of the scroll view
        let state = ScrollEdgeCalculator.calculateFade(offsetY: 200, distFromBottom: 0, fadeThreshold: 20)
        XCTAssertEqual(state.topFadeProgress, 1.0)
        XCTAssertEqual(state.bottomFadeProgress, 0.0)
    }
    
    public func testScrollingBackToTopClearsFade() {
        // When scrolled back to top and no overflow
        let state = ScrollEdgeCalculator.calculateFade(offsetY: 0, distFromBottom: 0, fadeThreshold: 20)
        XCTAssertEqual(state.topFadeProgress, 0.0)
        XCTAssertEqual(state.bottomFadeProgress, 0.0)
    }
    
    public func testNegativeOverscrollSafelyClamped() {
        // During rubber-band bounce above top
        let state = ScrollEdgeCalculator.calculateFade(offsetY: -30, distFromBottom: 0, fadeThreshold: 20)
        XCTAssertEqual(state.topFadeProgress, 0.0)
        XCTAssertEqual(state.bottomFadeProgress, 0.0)
    }
    
    public func testHorizontalRestingStateHasZeroFade() {
        // Tab bar at left start with overflowing tabs on right
        let state = ScrollEdgeCalculator.calculateFade(offset: 0, distFromEnd: 150, fadeThreshold: 12)
        XCTAssertEqual(state.startFadeProgress, 0.0)
        XCTAssertEqual(state.endFadeProgress, 1.0)
    }
    
    public func testHorizontalScrollingStartsFading() {
        // Tab bar scrolled 6pt of 12pt threshold
        let state = ScrollEdgeCalculator.calculateFade(offset: 6, distFromEnd: 144, fadeThreshold: 12)
        XCTAssertEqual(state.startFadeProgress, 0.5)
        XCTAssertEqual(state.endFadeProgress, 1.0)
    }
    
    public func testHorizontalReachingEndClearsTrailingFade() {
        // Scrolled all the way to right tab end
        let state = ScrollEdgeCalculator.calculateFade(offset: 150, distFromEnd: 0, fadeThreshold: 12)
        XCTAssertEqual(state.startFadeProgress, 1.0)
        XCTAssertEqual(state.endFadeProgress, 0.0)
    }
}
