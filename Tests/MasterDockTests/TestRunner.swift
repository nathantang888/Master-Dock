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
        await runTest("testCalendarAccountTypeProperties") {
            let c = CalendarServiceTests()
            c.testCalendarAccountTypeProperties()
        }
        await runTest("testAccountLinkingAndUnlinking") {
            let c = CalendarServiceTests()
            c.testAccountLinkingAndUnlinking()
        }
        await runTest("testMultipleAccountsLinking") {
            let c = CalendarServiceTests()
            c.testMultipleAccountsLinking()
        }
        await runTest("testCalendarMeetingAccountProperties") {
            let c = CalendarServiceTests()
            c.testCalendarMeetingAccountProperties()
        }
        await runTest("testICalendarParserSingleEvent") {
            let c = CalendarServiceTests()
            c.testICalendarParserSingleEvent()
        }
        await runTest("testICalendarParserUnfoldingAndSpecialCharacters") {
            let c = CalendarServiceTests()
            c.testICalendarParserUnfoldingAndSpecialCharacters()
        }
        await runTest("testUpdateAccountICS") {
            let c = CalendarServiceTests()
            c.testUpdateAccountICS()
        }
        await runTest("testCustomEventAddition") {
            let c = CalendarServiceTests()
            c.testCustomEventAddition()
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
        
        print("\n-> [Suite] Dock Slide Motion Tests:")
        await runTest("testOpenSpringSettlesQuickly") {
            DockSlideMotionTests().testOpenSpringSettlesQuickly()
        }
        await runTest("testCriticallyDampedCloseNeverOvershoots") {
            DockSlideMotionTests().testCriticallyDampedCloseNeverOvershoots()
        }
        await runTest("testSpringBehavesTheSameAt60And120Hz") {
            DockSlideMotionTests().testSpringBehavesTheSameAt60And120Hz()
        }
        await runTest("testReleaseVelocityCarriesIntoSpring") {
            DockSlideMotionTests().testReleaseVelocityCarriesIntoSpring()
        }
        await runTest("testFollowTracksFingerAndIgnoresStalls") {
            DockSlideMotionTests().testFollowTracksFingerAndIgnoresStalls()
        }
        
        print("\n-> [Suite] Calendar Account Migration Tests:")
        await runTest("testOldSavedAccountStillDecodes") {
            try CalendarAccountMigrationTests().testOldSavedAccountStillDecodes()
        }
        await runTest("testMacSourceIDRoundTrips") {
            try CalendarAccountMigrationTests().testMacSourceIDRoundTrips()
        }
        await runTest("testDetectedSourceLinkedState") {
            try CalendarAccountMigrationTests().testDetectedSourceLinkedState()
        }
        
        print("\n-> [Suite] Momentum Projection Tests:")
        await runTest("testProjectionMatchesAppleFormula") {
            MomentumProjectionTests().testProjectionMatchesAppleFormula()
        }
        await runTest("testQuickShortFlickOpensDock") {
            MomentumProjectionTests().testQuickShortFlickOpensDock()
        }
        await runTest("testSlowTinyNudgeDoesNotOpen") {
            MomentumProjectionTests().testSlowTinyNudgeDoesNotOpen()
        }
        await runTest("testPullingBackCancelsEvenAfterTravellingFar") {
            MomentumProjectionTests().testPullingBackCancelsEvenAfterTravellingFar()
        }
        
        print("\n-> [Suite] New Feature Tests (events, calculator, layout, clipboard):")
        await runTest("testParsesTitleTimeAndDuration") {
            NewFeatureTests().testParsesTitleTimeAndDuration()
        }
        await runTest("testDayWithoutTimeIsAllDay") {
            NewFeatureTests().testDayWithoutTimeIsAllDay()
        }
        await runTest("testNoDateGivesNothing") {
            NewFeatureTests().testNoDateGivesNothing()
        }
        await runTest("testOnlyRealMeetingLinksCount") {
            NewFeatureTests().testOnlyRealMeetingLinksCount()
        }
        await runTest("testCalculatorMath") {
            NewFeatureTests().testCalculatorMath()
        }
        await runTest("testCalculatorRejectsBadInputSafely") {
            NewFeatureTests().testCalculatorRejectsBadInputSafely()
        }
        await runTest("testLayoutReorderHideAndRename") {
            NewFeatureTests().testLayoutReorderHideAndRename()
        }
        await runTest("testLayoutIsSavedAndRestored") {
            NewFeatureTests().testLayoutIsSavedAndRestored()
        }
        await runTest("testPasswordManagerCopiesAreDetected") {
            NewFeatureTests().testPasswordManagerCopiesAreDetected()
        }
        
        print("\n-> [Suite] AI Memory & Modes Tests:")
        await runTest("testRemembersTheHouseDaysLater") {
            AIMemoryTests().testRemembersTheHouseDaysLater()
        }
        await runTest("testMemorySurvivesRestartAndCanBeForgotten") {
            AIMemoryTests().testMemorySurvivesRestartAndCanBeForgotten()
        }
        await runTest("testUnrelatedQuestionsDontPullMemories") {
            AIMemoryTests().testUnrelatedQuestionsDontPullMemories()
        }
        await runTest("testModeInstructions") {
            AIMemoryTests().testModeInstructions()
        }
        
        print("\n-> [Diagnostics] Real EventKit & Service Events:")
        await CalendarService.shared.refreshEvents()
        print("   • Active Accounts in Shared Service: \(CalendarService.shared.accounts.map { "\($0.name) (\($0.emailOrUsername)) [events: \($0.eventCount)]" })")
        print("   • Today's Events Count: \(CalendarService.shared.todayEvents.count)")
        print("   • Calendar accounts on this Mac:")
        for line in CalendarService.shared.macSourceDiagnostics() {
            print("     - \(line)")
        }
        print("   • Google accounts detected: \(CalendarService.shared.detectedSources.map { "\($0.email) linked=\($0.isLinked)" })")
        for (i, ev) in CalendarService.shared.todayEvents.enumerated() {
            print("     \(i+1). [\(ev.accountName ?? "")] [\(ev.calendarName ?? "")] '\(ev.title)' (\(ev.timeRangeString)) location=\(ev.location ?? "none") join=\(ev.joinURL?.absoluteString ?? "none")")
        }
        
        print("\n==================================================")
        print("SUMMARY: \(passed) Total Tests | All \(passed) Passed | 0 Failed")
        print("==================================================")
        print("🎉 ALL TEST SUITES PASSED FLAWLESSLY!\n")
    }
}
