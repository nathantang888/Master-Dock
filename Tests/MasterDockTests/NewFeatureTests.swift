import Foundation
import AppKit
import MasterDockServices
import MasterDockUI

public struct NewFeatureTests {
    public init() {}

    // MARK: Natural-language events

    public func testParsesTitleTimeAndDuration() {
        guard let e = NaturalLanguageEventParser.parse("Calc study tomorrow at 4pm for 2 hours") else {
            XCTAssertTrue(false, "should parse"); return
        }
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(e.title, "Calc study")
        XCTAssertTrue(cal.isDate(e.start, inSameDayAs: tomorrow), "starts tomorrow")
        XCTAssertEqual(cal.component(.hour, from: e.start), 16)
        XCTAssertEqual(e.end.timeIntervalSince(e.start), 7200, accuracy: 1)
        XCTAssertFalse(e.isAllDay)
    }

    public func testDayWithoutTimeIsAllDay() {
        guard let e = NaturalLanguageEventParser.parse("Dentist tomorrow") else {
            XCTAssertTrue(false, "should parse"); return
        }
        XCTAssertEqual(e.title, "Dentist")
        XCTAssertTrue(e.isAllDay)
    }

    public func testNoDateGivesNothing() {
        XCTAssertTrue(NaturalLanguageEventParser.parse("just some words") == nil)
        XCTAssertTrue(NaturalLanguageEventParser.parse("") == nil)
    }

    // MARK: Meeting links

    public func testOnlyRealMeetingLinksCount() {
        XCTAssertTrue(ICalendarParser.isMeetingURL(URL(string: "https://us02web.zoom.us/j/123456")!))
        XCTAssertTrue(ICalendarParser.isMeetingURL(URL(string: "https://meet.google.com/abc-defg-hij")!))
        XCTAssertFalse(ICalendarParser.isMeetingURL(URL(string: "https://evhs.myschoolcentral.com")!))
        XCTAssertFalse(ICalendarParser.isMeetingURL(URL(string: "https://notzoom.us.evil.com/j/1")!))
    }

    // MARK: Calculator

    public func testCalculatorMath() {
        XCTAssertEqual(MathEvaluator.evaluate("12.5 * (3 + 4)") ?? 0, 87.5, accuracy: 0.0001)
        XCTAssertEqual(MathEvaluator.evaluate("2 ^ 3 ^ 2") ?? 0, 512, accuracy: 0.0001)
        XCTAssertEqual(MathEvaluator.evaluate("-4 + 10 / 4") ?? 0, -1.5, accuracy: 0.0001)
        XCTAssertEqual(MathEvaluator.evaluate("7 % 3") ?? 0, 1, accuracy: 0.0001)
    }

    public func testCalculatorRejectsBadInputSafely() {
        XCTAssertTrue(MathEvaluator.evaluate("2 +") == nil)
        XCTAssertTrue(MathEvaluator.evaluate("(1 + 2") == nil)
        XCTAssertTrue(MathEvaluator.evaluate("5 / 0") == nil)
        XCTAssertTrue(MathEvaluator.evaluate("rm -rf") == nil)
        XCTAssertEqual(MathEvaluator.format(4), "4")
    }

    // MARK: Widget layout

    private func freshStore() -> DockLayoutStore {
        let suite = "MasterDockTests.layout.\(UUID().uuidString)"
        return DockLayoutStore(storageKey: "layout", defaults: UserDefaults(suiteName: suite)!)
    }

    public func testLayoutReorderHideAndRename() {
        let store = freshStore()
        XCTAssertEqual(store.visibleWidgets.first?.kind, .ai)
        store.move(.ai, by: 1)
        XCTAssertEqual(store.visibleWidgets.first?.kind, .media)
        store.setVisible(.clipboard, false)
        XCTAssertFalse(store.visibleWidgets.contains { $0.kind == .clipboard })
        store.setVisible(.notes, true)
        XCTAssertEqual(store.visibleWidgets.last?.kind, .notes)
        store.rename(.calendar, to: "School")
        XCTAssertEqual(store.title(for: .calendar) ?? "", "School")
        store.rename(.calendar, to: "  ")
        XCTAssertTrue(store.title(for: .calendar) == nil, "blank name resets to default")
    }

    public func testLayoutIsSavedAndRestored() {
        let suite = "MasterDockTests.layout.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let first = DockLayoutStore(storageKey: "layout", defaults: defaults)
        first.move(.calendar, before: .ai)
        first.rename(.media, to: "Tunes")
        let second = DockLayoutStore(storageKey: "layout", defaults: defaults)
        XCTAssertEqual(second.visibleWidgets.first?.kind, .calendar)
        XCTAssertEqual(second.title(for: .media) ?? "", "Tunes")
        XCTAssertEqual(second.widgets.count, DockWidgetKind.allCases.count)
    }

    // MARK: Clipboard privacy

    public func testPasswordManagerCopiesAreDetected() {
        XCTAssertTrue(ClipboardMonitorService.isPrivateCopy(types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]))
        XCTAssertFalse(ClipboardMonitorService.isPrivateCopy(types: [.string]))
    }
}
