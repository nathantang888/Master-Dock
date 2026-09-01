import Foundation
import MasterDockCore
import MasterDockServices
import MasterDockAI
import MasterDockUI

@main
struct TestRunner {
    static func main() async {
        print("==================================================")
        print("          MASTER DOCK TEST SUITE RUNNER           ")
        print("==================================================")
        
        var passed = 0
        
        func runTest(_ name: String, block: () async throws -> Void) async {
            print("   • [TEST] \(name)... ", terminator: "")
            do {
                try await block()
                passed += 1
                print("PASSED ✅")
            } catch {
                print("FAILED ❌ (\(error))")
                exit(1)
            }
        }
        
        print("\n-> [Suite] Gesture State Machine Tests:")
        await runTest("testInitialStateIsIdle") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testInitialStateIsIdle()
        }
        await runTest("testLeftEdgeTwoFingerSwipeStartsTracking") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeTwoFingerSwipeStartsTracking()
        }
        await runTest("testLeftEdgeSwipeProgressAndCommitStandardDock") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipeProgressAndCommitStandardDock()
        }
        await runTest("testLeftEdgeSwipePastHalfCommitsVoiceMode") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipePastHalfCommitsVoiceMode()
        }
        await runTest("testTopEdgeTwoFingerSwipeCommitsVoiceMode") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testTopEdgeTwoFingerSwipeCommitsVoiceMode()
        }
        await runTest("testSingleFingerIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testSingleFingerIgnored()
        }
        await runTest("testLeftEdgeSwipeWhileOpenClosesDock") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipeWhileOpenClosesDock()
        }
        await runTest("testScrollingWhileOpenLeavesDockOpen") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testScrollingWhileOpenLeavesDockOpen()
        }
        
        print("\n-> [Suite] Clipboard Monitor Tests:")
        await runTest("testClipboardItemCreation") {
            let c = ClipboardMonitorTests()
            c.testClipboardItemCreation()
        }
        await runTest("testClipboardTypeClassification") {
            let c = ClipboardMonitorTests()
            c.testClipboardTypeClassification()
        }
        
        print("\n-> [Suite] Calendar Service Tests:")
        await runTest("testMeetingCountdownFormatting") {
            let c = CalendarServiceTests()
            c.testMeetingCountdownFormatting()
        }
        await runTest("testHappeningNowCountdown") {
            let c = CalendarServiceTests()
            c.testHappeningNowCountdown()
        }
        
        print("\n-> [Suite] Daily Checklist Tests:")
        await runTest("testChecklistProgressCalculation") {
            let c = ChecklistServiceTests()
            c.testChecklistProgressCalculation()
        }
        
        print("\n-> [Suite] AI & Prompt Library Tests:")
        await runTest("testMockAIServiceStreaming") {
            let a = AIServiceMockTests()
            try await a.testMockAIServiceStreaming()
        }
        await runTest("testAppleIntelligenceStreaming") {
            let a = AIServiceMockTests()
            try await a.testAppleIntelligenceStreaming()
        }
        await runTest("testPromptTemplateResolution") {
            let a = AIServiceMockTests()
            a.testPromptTemplateResolution()
        }
        
        print("\n-> [Suite] Media Controller & Multi-Platform Tests:")
        await runTest("testMediaSourceProperties") {
            let m = MediaServiceTests()
            m.testMediaSourceProperties()
        }
        await runTest("testMediaTrackFormatting") {
            let m = MediaServiceTests()
            m.testMediaTrackFormatting()
        }
        await runTest("testMediaPlaylistAndTracks") {
            let m = MediaServiceTests()
            m.testMediaPlaylistAndTracks()
        }
        await runTest("testPlaybackControlsMath") {
            let m = MediaServiceTests()
            m.testPlaybackControlsMath()
        }
        await runTest("testVolumeClamping") {
            let m = MediaServiceTests()
            m.testVolumeClamping()
        }
        await runTest("testShuffleAndRepeatCycling") {
            let m = MediaServiceTests()
            m.testShuffleAndRepeatCycling()
        }
        await runTest("testLikedTracks") {
            let m = MediaServiceTests()
            m.testLikedTracks()
        }
        await runTest("testCustomPlaylists") {
            let m = MediaServiceTests()
            m.testCustomPlaylists()
        }
        await runTest("testPlatformInformation") {
            let m = MediaServiceTests()
            m.testPlatformInformation()
        }
        
        print("\n-> [Suite] Dynamic Scroll Edge Fade Tests:")
        await runTest("testInitialRestingStateHasZeroFade") {
            let s = ScrollEdgeFadeTests()
            s.testInitialRestingStateHasZeroFade()
        }
        await runTest("testScrollingDownStartsFading") {
            let s = ScrollEdgeFadeTests()
            s.testScrollingDownStartsFading()
        }
        await runTest("testFullyScrolledPastThreshold") {
            let s = ScrollEdgeFadeTests()
            s.testFullyScrolledPastThreshold()
        }
        await runTest("testReachingBottomClearsBottomFade") {
            let s = ScrollEdgeFadeTests()
            s.testReachingBottomClearsBottomFade()
        }
        await runTest("testScrollingBackToTopClearsFade") {
            let s = ScrollEdgeFadeTests()
            s.testScrollingBackToTopClearsFade()
        }
        await runTest("testNegativeOverscrollSafelyClamped") {
            let s = ScrollEdgeFadeTests()
            s.testNegativeOverscrollSafelyClamped()
        }
        await runTest("testHorizontalRestingStateHasZeroFade") {
            let s = ScrollEdgeFadeTests()
            s.testHorizontalRestingStateHasZeroFade()
        }
        await runTest("testHorizontalScrollingStartsFading") {
            let s = ScrollEdgeFadeTests()
            s.testHorizontalScrollingStartsFading()
        }
        await runTest("testHorizontalReachingEndClearsTrailingFade") {
            let s = ScrollEdgeFadeTests()
            s.testHorizontalReachingEndClearsTrailingFade()
        }
        
        print("\n==================================================")
        print("SUMMARY: \(passed) Total Tests | All \(passed) Passed | 0 Failed")
        print("==================================================")
        print("🎉 ALL TEST SUITES PASSED FLAWLESSLY!\n")
    }
}
