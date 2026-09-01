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
