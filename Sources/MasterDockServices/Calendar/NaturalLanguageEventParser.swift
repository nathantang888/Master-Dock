import Foundation

/// Turns a typed sentence like "Calc study Friday 4pm for 2 hours" into an event.
/// Uses Apple's built-in date detection (the same one Mail and Notes use), so it understands
/// "tomorrow", "next Tuesday at 3", "Nov 12 noon", "tonight", etc.
public enum NaturalLanguageEventParser {
    public struct ParsedEvent: Equatable, Sendable {
        public var title: String
        public var start: Date
        public var end: Date
        public var isAllDay: Bool
    }

    /// Returns nil when there is no title or no date/time in the text.
    public static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedEvent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var working = trimmed

        // 1. Duration: "for 2 hours", "for 90 min", "for 1.5 hrs", "for an hour"
        var duration: TimeInterval = 3600
        var hasExplicitDuration = false
        let durationPattern = #"\bfor\s+(an?|\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b"#
        if let match = firstMatch(durationPattern, in: working) {
            let amountText = substring(working, match.range(at: 1)).lowercased()
            let unit = substring(working, match.range(at: 2)).lowercased()
            let amount = (amountText == "a" || amountText == "an") ? 1 : (Double(amountText) ?? 1)
            duration = unit.hasPrefix("m") ? amount * 60 : amount * 3600
            hasExplicitDuration = true
            working = remove(match.range, from: working)
        }

        // 2. All day
        var isAllDay = false
        if let match = firstMatch(#"\ball[\s-]?day\b"#, in: working) {
            isAllDay = true
            working = remove(match.range, from: working)
        }

        // 3. Date and time
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
              let dateMatch = detector.firstMatch(in: working, options: [], range: NSRange(working.startIndex..., in: working)),
              var start = dateMatch.date else { return nil }

        let dateText = substring(working, dateMatch.range).lowercased()
        let mentionsTime = dateText.range(of: #"\d|noon|midnight|morning|afternoon|evening|tonight"#, options: .regularExpression) != nil

        if isAllDay || !mentionsTime {
            // A date without a time ("Friday") becomes an all-day event on that day.
            isAllDay = true
            start = calendar.startOfDay(for: start)
        }

        // "3 to 5pm" style ranges come back with their own length.
        if !hasExplicitDuration && dateMatch.duration > 0 {
            duration = dateMatch.duration
        }

        let end: Date
        if isAllDay {
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        } else {
            end = start.addingTimeInterval(duration)
        }

        // 4. Title: what's left, minus filler words around the date ("at", "on", "from").
        working = remove(dateMatch.range, from: working)
        var title = working
            .replacingOccurrences(of: #"\s+(at|on|from|by|this|next|@)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"^\s*(at|on|from|this|next)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if let first = title.first {
            title = first.uppercased() + title.dropFirst()
        }
        guard !title.isEmpty else { return nil }

        return ParsedEvent(title: title, start: start, end: end, isAllDay: isAllDay)
    }

    // MARK: - Helpers

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        return regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
    }

    private static func substring(_ text: String, _ range: NSRange) -> String {
        guard let r = Range(range, in: text) else { return "" }
        return String(text[r])
    }

    private static func remove(_ range: NSRange, from text: String) -> String {
        guard let r = Range(range, in: text) else { return text }
        var copy = text
        copy.replaceSubrange(r, with: " ")
        return copy
    }
}
