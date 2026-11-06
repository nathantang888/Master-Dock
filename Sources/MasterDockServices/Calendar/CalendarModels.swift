import Foundation
import SwiftUI

/// Supported calendar service provider platforms
public enum CalendarAccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleCalendar = "Apple Calendar"
    case googleCalendar = "Google Calendar"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .appleCalendar: return "calendar"
        case .googleCalendar: return "g.circle.fill"
        }
    }
    
    public var brandAccentColor: Color {
        switch self {
        case .appleCalendar: return Color(red: 0.98, green: 0.24, blue: 0.35) // Apple Red/Coral
        case .googleCalendar: return Color(red: 0.26, green: 0.52, blue: 0.96) // Google Blue
        }
    }
    
    public var shortName: String {
        switch self {
        case .appleCalendar: return "Apple"
        case .googleCalendar: return "Google"
        }
    }
}

/// Represents a linked user calendar account (Apple Calendar or Google Calendar)
public struct CalendarAccount: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var accountType: CalendarAccountType
    public var emailOrUsername: String
    public var isLinked: Bool
    public var isEnabled: Bool
    public var icsURL: String?
    public var colorHex: String?
    public var lastSyncedAt: Date?
    public var eventCount: Int
    /// The Mac Calendar account (EKSource) this Google account syncs from, if it is signed in on this Mac.
    public var eventKitSourceID: String?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        accountType: CalendarAccountType,
        emailOrUsername: String = "",
        isLinked: Bool = true,
        isEnabled: Bool = true,
        icsURL: String? = nil,
        colorHex: String? = nil,
        lastSyncedAt: Date? = nil,
        eventCount: Int = 0,
        eventKitSourceID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.accountType = accountType
        self.emailOrUsername = emailOrUsername
        self.isLinked = isLinked
        self.isEnabled = isEnabled
        self.icsURL = icsURL
        self.colorHex = colorHex
        self.lastSyncedAt = lastSyncedAt
        self.eventCount = eventCount
        self.eventKitSourceID = eventKitSourceID
    }
}

/// A Google account that is signed in on this Mac and can be linked with one click.
public struct DetectedCalendarSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let calendarCount: Int
    /// The Master Dock account showing this source, or nil if it is not linked.
    public let linkedAccountID: String?
    
    public var isLinked: Bool { linkedAccountID != nil }
    
    public init(id: String, email: String, calendarCount: Int, linkedAccountID: String?) {
        self.id = id
        self.email = email
        self.calendarCount = calendarCount
        self.linkedAccountID = linkedAccountID
    }
}

/// Represents a single scheduled calendar event or meeting from any linked account
public struct CalendarMeeting: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let joinURL: URL?
    public let isAllDay: Bool
    public let accountID: String?
    public let accountName: String?
    public let accountType: CalendarAccountType?
    public let calendarName: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        joinURL: URL? = nil,
        isAllDay: Bool = false,
        accountID: String? = nil,
        accountName: String? = nil,
        accountType: CalendarAccountType? = nil,
        calendarName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.joinURL = joinURL
        self.isAllDay = isAllDay
        self.accountID = accountID
        self.accountName = accountName
        self.accountType = accountType
        self.calendarName = calendarName
    }
    
    public var timeRangeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
    
    public var countdownStatus: String {
        let now = Date()
        if now >= startDate && now <= endDate {
            return "Happening Now"
        } else if startDate > now {
            let diffMinutes = Int(startDate.timeIntervalSince(now) / 60)
            if diffMinutes < 60 {
                return "in \(diffMinutes) min"
            } else {
                let hours = diffMinutes / 60
                let mins = diffMinutes % 60
                return "in \(hours)h \(mins)m"
            }
        } else {
            return "Completed"
        }
    }
}

/// Lightweight RFC 5545 iCalendar (.ics) parser for Google Calendar feeds
public struct ICalendarParser {
    public static func parse(icsContent: String, account: CalendarAccount, forDay date: Date = Date()) -> [CalendarMeeting] {
        let unfolded = icsContent
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
        
        let lines = unfolded.components(separatedBy: .newlines)
        
        var meetings: [CalendarMeeting] = []
        var inEvent = false
        var currentSummary = ""
        var currentDescription = ""
        var currentLocation = ""
        var currentURLString = ""
        var currentStart: Date?
        var currentEnd: Date?
        var isAllDay = false
        var eventId = UUID().uuidString
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.uppercased() == "BEGIN:VEVENT" {
                inEvent = true
                currentSummary = ""
                currentDescription = ""
                currentLocation = ""
                currentURLString = ""
                currentStart = nil
                currentEnd = nil
                isAllDay = false
                eventId = UUID().uuidString
            } else if line.uppercased() == "END:VEVENT" {
                inEvent = false
                if let start = currentStart {
                    let end = currentEnd ?? start.addingTimeInterval(3600)
                    // Check if overlaps target day
                    if end > startOfDay && start < endOfDay {
                        let joinURL = extractMeetingURL(from: "\(currentDescription) \(currentLocation) \(currentURLString)")
                            ?? URL(string: currentURLString)
                        
                        let meeting = CalendarMeeting(
                            id: eventId,
                            title: currentSummary.isEmpty ? "Untitled Event" : currentSummary,
                            startDate: start,
                            endDate: end,
                            location: currentLocation.isEmpty ? nil : currentLocation,
                            joinURL: joinURL,
                            isAllDay: isAllDay,
                            accountID: account.id,
                            accountName: account.name,
                            accountType: account.accountType,
                            calendarName: account.accountType.rawValue
                        )
                        meetings.append(meeting)
                    }
                }
            } else if inEvent {
                if line.hasPrefix("UID:") {
                    eventId = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("SUMMARY:") {
                    currentSummary = String(line.dropFirst(8))
                        .replacingOccurrences(of: "\\,", with: ",")
                        .replacingOccurrences(of: "\\;", with: ";")
                        .replacingOccurrences(of: "\\n", with: "\n")
                } else if line.hasPrefix("DESCRIPTION:") {
                    currentDescription = String(line.dropFirst(12))
                        .replacingOccurrences(of: "\\,", with: ",")
                        .replacingOccurrences(of: "\\;", with: ";")
                        .replacingOccurrences(of: "\\n", with: "\n")
                } else if line.hasPrefix("LOCATION:") {
                    currentLocation = String(line.dropFirst(9))
                        .replacingOccurrences(of: "\\,", with: ",")
                        .replacingOccurrences(of: "\\;", with: ";")
                        .replacingOccurrences(of: "\\n", with: "\n")
                } else if line.hasPrefix("URL:") || line.hasPrefix("URL;") {
                    if let colonIndex = line.firstIndex(of: ":") {
                        currentURLString = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    }
                } else if line.hasPrefix("DTSTART") {
                    let (parsedDate, allDay) = parseICSDate(line: line)
                    currentStart = parsedDate
                    if allDay { isAllDay = true }
                } else if line.hasPrefix("DTEND") {
                    let (parsedDate, _) = parseICSDate(line: line)
                    currentEnd = parsedDate
                }
            }
        }
        
        return meetings
    }
    
    private static func parseICSDate(line: String) -> (Date?, Bool) {
        guard let colonIndex = line.firstIndex(of: ":") else { return (nil, false) }
        let datePart = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        let isAllDay = line.contains("VALUE=DATE") || datePart.count == 8
        
        let formatters: [DateFormatter] = [
            {
                let df = DateFormatter()
                df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                df.timeZone = TimeZone(secondsFromGMT: 0)
                return df
            }(),
            {
                let df = DateFormatter()
                df.dateFormat = "yyyyMMdd'T'HHmmss"
                df.timeZone = .current
                return df
            }(),
            {
                let df = DateFormatter()
                df.dateFormat = "yyyyMMdd"
                df.timeZone = .current
                return df
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: datePart) {
                return (date, isAllDay)
            }
        }
        return (nil, isAllDay)
    }
    
    /// Hosts of real video-meeting services. Only links to these get a Join button.
    public static let meetingHosts = [
        "zoom.us", "zoomgov.com", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "facetime.apple.com", "whereby.com", "meet.jit.si", "chime.aws",
        "gotomeeting.com", "meet.goto.com", "bluejeans.com"
    ]
    
    /// True only for links that open an actual meeting (not any website attached to an event).
    public static func isMeetingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    
    public static func extractMeetingURL(from text: String) -> URL? {
        let patterns = [
            "https://[a-zA-Z0-9.-]*zoom(gov)?\\.(us|com)/(j|my|w)/[a-zA-Z0-9?=_&./-]+",
            "https://meet\\.google\\.com/[a-zA-Z0-9-]+",
            "https://teams\\.(microsoft|live)\\.com/[a-zA-Z0-9%?=_&./:@-]+",
            "https://[a-zA-Z0-9.-]*webex\\.com/[a-zA-Z0-9%?=_&./-]+",
            "https://facetime\\.apple\\.com/join[a-zA-Z0-9%?=_&#./-]*",
            "https://whereby\\.com/[a-zA-Z0-9-]+",
            "https://meet\\.jit\\.si/[a-zA-Z0-9-]+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                if let range = Range(match.range, in: text) {
                    return URL(string: String(text[range]))
                }
            }
        }
        return nil
    }
}

/// Represents a persistent custom event added to a linked calendar account
public struct SavedCustomCalendarEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var accountID: String
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var location: String?
    public var joinURLString: String?
    public var isAllDay: Bool
    
    public init(
        id: String = UUID().uuidString,
        accountID: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        joinURLString: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.accountID = accountID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.joinURLString = joinURLString
        self.isAllDay = isAllDay
    }
}
