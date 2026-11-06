import Foundation
import MasterDockServices

final class CalendarServiceTests {
    func testMeetingCountdownFormatting() {
        let now = Date()
        let upcoming = CalendarMeeting(
            title: "Sprint Standup",
            startDate: now.addingTimeInterval(1200), // 20 mins in future
            endDate: now.addingTimeInterval(3000),
            location: "Virtual"
        )
        
        XCTAssertTrue(upcoming.countdownStatus.contains("min") || upcoming.countdownStatus.contains("in"))
    }
    
    func testHappeningNowCountdown() {
        let now = Date()
        let active = CalendarMeeting(
            title: "Current Sync",
            startDate: now.addingTimeInterval(-300), // 5 min ago
            endDate: now.addingTimeInterval(1500),  // 25 min in future
            location: "Office"
        )
        
        XCTAssertEqual(active.countdownStatus, "Happening Now")
    }
    
    func testCalendarAccountTypeProperties() {
        let google = CalendarAccountType.googleCalendar
        let apple = CalendarAccountType.appleCalendar
        
        XCTAssertEqual(google.rawValue, "Google Calendar")
        XCTAssertEqual(apple.rawValue, "Apple Calendar")
        XCTAssertEqual(google.shortName, "Google")
        XCTAssertEqual(apple.shortName, "Apple")
        XCTAssertEqual(google.iconName, "g.circle.fill")
        XCTAssertEqual(apple.iconName, "calendar")
    }
    
    func testAccountLinkingAndUnlinking() {
        let testKey = "test_cal_acc_\(UUID().uuidString)"
        let service = CalendarService(accountsStorageKey: testKey, autoRefresh: false)
        let initialCount = service.accounts.count
        
        let testAccount = CalendarAccount(
            name: "Test Personal Google",
            accountType: .googleCalendar,
            emailOrUsername: "user.test@gmail.com",
            isLinked: true,
            isEnabled: true
        )
        
        service.linkAccount(testAccount)
        XCTAssertEqual(service.accounts.count, initialCount + 1)
        
        let found = service.accounts.first(where: { $0.id == testAccount.id })
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Test Personal Google")
        XCTAssertTrue(found?.isLinked == true)
        XCTAssertTrue(found?.isEnabled == true)
        
        service.toggleAccountEnabled(id: testAccount.id)
        let toggled = service.accounts.first(where: { $0.id == testAccount.id })
        XCTAssertFalse(toggled?.isEnabled == true)
        
        service.unlinkAccount(id: testAccount.id)
        let unlinked = service.accounts.first(where: { $0.id == testAccount.id })
        XCTAssertFalse(unlinked?.isLinked == true)
        
        service.removeAccount(id: testAccount.id)
        XCTAssertEqual(service.accounts.count, initialCount)
    }
    
    func testMultipleAccountsLinking() {
        let testKey = "test_cal_acc_\(UUID().uuidString)"
        let service = CalendarService(accountsStorageKey: testKey, autoRefresh: false)
        
        let acc1 = CalendarAccount(name: "Work Google", accountType: .googleCalendar, emailOrUsername: "work@corp.com")
        let acc2 = CalendarAccount(name: "Personal Google", accountType: .googleCalendar, emailOrUsername: "me@gmail.com")
        let acc3 = CalendarAccount(name: "iCloud Family", accountType: .appleCalendar, emailOrUsername: "family@icloud.com")
        
        service.linkAccount(acc1)
        service.linkAccount(acc2)
        service.linkAccount(acc3)
        
        let googleAccounts = service.accounts.filter { $0.accountType == .googleCalendar }
        let appleAccounts = service.accounts.filter { $0.accountType == .appleCalendar }
        
        XCTAssertTrue(googleAccounts.count >= 2)
        XCTAssertTrue(appleAccounts.count >= 1)
        
        // Clean up
        service.removeAccount(id: acc1.id)
        service.removeAccount(id: acc2.id)
        service.removeAccount(id: acc3.id)
    }
    
    func testCalendarMeetingAccountProperties() {
        let now = Date()
        let meeting = CalendarMeeting(
            title: "Sprint Review",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            location: "Google Meet",
            joinURL: URL(string: "https://meet.google.com/abc-defg-hij"),
            isAllDay: false,
            accountID: "acc-123",
            accountName: "Work Google Calendar",
            accountType: .googleCalendar,
            calendarName: "Engineering"
        )
        
        XCTAssertEqual(meeting.title, "Sprint Review")
        XCTAssertEqual(meeting.accountID, "acc-123")
        XCTAssertEqual(meeting.accountName, "Work Google Calendar")
        XCTAssertEqual(meeting.accountType, .googleCalendar)
        XCTAssertEqual(meeting.calendarName, "Engineering")
        XCTAssertNotNil(meeting.joinURL)
    }
    
    func testICalendarParserSingleEvent() {
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        
        let dateString = String(format: "%04d%02d%02d", year, month, day)
        
        let icsSample = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Google Inc//Google Calendar 70.9054//EN
        BEGIN:VEVENT
        UID:google-event-test-12345
        DTSTART:\(dateString)T140000Z
        DTEND:\(dateString)T150000Z
        SUMMARY:Google Meet Strategy Sync
        DESCRIPTION:Join with Google Meet: https://meet.google.com/test-sync-123
        LOCATION:Online / Google Meet
        END:VEVENT
        END:VCALENDAR
        """
        
        let account = CalendarAccount(
            id: "test-google-account",
            name: "Work Google Calendar",
            accountType: .googleCalendar,
            emailOrUsername: "test@google.com"
        )
        
        let meetings = ICalendarParser.parse(icsContent: icsSample, account: account, forDay: today)
        XCTAssertEqual(meetings.count, 1)
        XCTAssertEqual(meetings[0].title, "Google Meet Strategy Sync")
        XCTAssertEqual(meetings[0].accountName, "Work Google Calendar")
        XCTAssertEqual(meetings[0].accountType, .googleCalendar)
        XCTAssertNotNil(meetings[0].joinURL)
        XCTAssertEqual(meetings[0].joinURL?.absoluteString, "https://meet.google.com/test-sync-123")
    }
    
    func testICalendarParserUnfoldingAndSpecialCharacters() {
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        let day = calendar.component(.day, from: today)
        
        let dateString = String(format: "%04d%02d%02d", year, month, day)
        
        let icsSample = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:folded-test-456
        DTSTART:\(dateString)T160000Z
        DTEND:\(dateString)T170000Z
        SUMMARY:Very Long Event Title That Has
          Been Folded Across Multiple Lines
        DESCRIPTION:Notes with comma\\, semicolon\\; and
          escaped line\\nbreaks
        LOCATION:Meeting Room 4B
        END:VEVENT
        END:VCALENDAR
        """
        
        let account = CalendarAccount(
            name: "Apple Calendar",
            accountType: .appleCalendar
        )
        
        let meetings = ICalendarParser.parse(icsContent: icsSample, account: account, forDay: today)
        XCTAssertEqual(meetings.count, 1)
        XCTAssertTrue(meetings[0].title.contains("Very Long Event Title"))
        XCTAssertTrue(meetings[0].title.contains("Been Folded Across Multiple Lines"))
        XCTAssertEqual(meetings[0].location, "Meeting Room 4B")
    }
    
    func testUpdateAccountICS() {
        let testKey = "test_cal_acc_\(UUID().uuidString)"
        let service = CalendarService(accountsStorageKey: testKey, autoRefresh: false)
        let testAcc = CalendarAccount(
            name: "Work Calendar",
            accountType: .googleCalendar,
            emailOrUsername: "test@google.com"
        )
        service.linkAccount(testAcc)
        
        let urlStr = "https://calendar.google.com/calendar/ical/test/basic.ics"
        service.updateAccountICS(id: testAcc.id, icsURL: urlStr)
        
        let updated = service.accounts.first(where: { $0.id == testAcc.id })
        XCTAssertEqual(updated?.icsURL, urlStr)
    }
    
    func testCustomEventAddition() {
        let testKey = "test_cal_acc_\(UUID().uuidString)"
        let evKey = "test_cal_ev_\(UUID().uuidString)"
        let service = CalendarService(accountsStorageKey: testKey, customEventsStorageKey: evKey, autoRefresh: false)
        let testAcc = CalendarAccount(
            name: "Alex Work Test",
            accountType: .googleCalendar,
            emailOrUsername: "test@gmail.com"
        )
        service.linkAccount(testAcc)
        
        let now = Date()
        service.addCustomEvent(
            to: testAcc.id,
            title: "Executive Review",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            location: "Room 101",
            joinURL: URL(string: "https://meet.google.com/xyz"),
            isAllDay: false
        )
    }
}

final class ChecklistServiceTests {
    func testChecklistProgressCalculation() {
        let service = ChecklistService()
        service.clearCompleted()
        
        // Start fresh
        while !service.items.isEmpty {
            service.removeItem(service.items[0])
        }
        
        service.addItem(title: "Task 1")
        service.addItem(title: "Task 2")
        service.addItem(title: "Task 3")
        service.addItem(title: "Task 4")
        
        XCTAssertEqual(service.totalCount, 4)
        XCTAssertEqual(service.completedCount, 0)
        XCTAssertEqual(service.progressPercentage, 0.0)
        
        service.toggleItem(service.items[0])
        service.toggleItem(service.items[1])
        
        XCTAssertEqual(service.completedCount, 2)
        XCTAssertEqual(service.progressPercentage, 0.5)
    }
}
