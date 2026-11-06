import Foundation
import MasterDockServices

public struct CalendarAccountMigrationTests {
    public init() {}
    
    /// Accounts saved by older versions have no eventKitSourceID. They must still load.
    public func testOldSavedAccountStillDecodes() throws {
        let oldJSON = """
        [{"id":"abc","name":"Nathan Work","accountType":"Google Calendar","emailOrUsername":"me@gmail.com","isLinked":true,"isEnabled":true,"eventCount":0}]
        """
        let decoded = try JSONDecoder().decode([CalendarAccount].self, from: Data(oldJSON.utf8))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].emailOrUsername, "me@gmail.com")
        XCTAssertTrue(decoded[0].eventKitSourceID == nil, "old accounts start without a Mac source")
    }
    
    public func testMacSourceIDRoundTrips() throws {
        let account = CalendarAccount(name: "School", accountType: .googleCalendar, emailOrUsername: "me@school.edu", eventKitSourceID: "SOURCE-123")
        let data = try JSONEncoder().encode([account])
        let decoded = try JSONDecoder().decode([CalendarAccount].self, from: data)
        XCTAssertEqual(decoded[0].eventKitSourceID ?? "", "SOURCE-123")
    }
    
    public func testDetectedSourceLinkedState() {
        let linked = DetectedCalendarSource(id: "a", email: "me@gmail.com", calendarCount: 3, linkedAccountID: "acc-1")
        let unlinked = DetectedCalendarSource(id: "b", email: "me@school.edu", calendarCount: 1, linkedAccountID: nil)
        XCTAssertTrue(linked.isLinked)
        XCTAssertFalse(unlinked.isLinked)
    }
}
