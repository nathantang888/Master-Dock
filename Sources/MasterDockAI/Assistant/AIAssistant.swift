import Foundation
import AppKit
import ApplicationServices

// MARK: - Modes

public enum AIAssistantMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Plain assistant, no personal info.
    case generic
    /// Uses the user's name, background and preferred style.
    case personal
    /// Can read the dock (clipboard, events, music, checklist, notes) and, with permission,
    /// the app you're in and your selected text.
    case computer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .generic: return "General"
        case .personal: return "Personal"
        case .computer: return "Computer"
        }
    }

    public var iconName: String {
        switch self {
        case .generic: return "sparkles"
        case .personal: return "person.crop.circle"
        case .computer: return "desktopcomputer"
        }
    }

    public var summary: String {
        switch self {
        case .generic: return "A general assistant. Doesn't use anything about you."
        case .personal: return "Tailored to you: your name, what you've told it about yourself, and how you like answers."
        case .computer: return "Can see what's in your dock and, if you allow it, the app you're using and your selected text."
        }
    }
}

public enum AIResponseStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case concise, balanced, detailed
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    var instruction: String {
        switch self {
        case .concise: return "Keep answers short and to the point."
        case .balanced: return "Give clear answers with a little explanation."
        case .detailed: return "Give thorough, detailed answers with examples."
        }
    }
}

/// What Computer mode is allowed to read. Each one is off until the user turns it on.
public enum AIComputerSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case dock, currentApp, selectedText
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .dock: return "Your dock"
        case .currentApp: return "The app you're using"
        case .selectedText: return "Text you've selected"
        }
    }
    public var detail: String {
        switch self {
        case .dock: return "Clipboard history, today's events, what's playing, your checklist and quick notes."
        case .currentApp: return "The name and window title of the app you were in before opening the dock."
        case .selectedText: return "Highlighted text in that app. Needs macOS Accessibility permission."
        }
    }
}

// MARK: - Settings

/// AI preferences, saved on this Mac.
public final class AIAssistantSettings: ObservableObject {
    public static let shared = AIAssistantSettings()

    private let defaults: UserDefaults

    @Published public var mode: AIAssistantMode { didSet { defaults.set(mode.rawValue, forKey: "ai_mode") } }
    @Published public var memoryEnabled: Bool { didSet { defaults.set(memoryEnabled, forKey: "ai_memory_enabled") } }
    /// The user has read and accepted how memory works.
    @Published public var memoryConsentGiven: Bool { didSet { defaults.set(memoryConsentGiven, forKey: "ai_memory_consent") } }

    // Personal mode
    @Published public var preferredName: String { didSet { defaults.set(preferredName, forKey: "ai_personal_name") } }
    @Published public var aboutMe: String { didSet { defaults.set(aboutMe, forKey: "ai_personal_about") } }
    @Published public var customInstructions: String { didSet { defaults.set(customInstructions, forKey: "ai_personal_instructions") } }
    @Published public var responseStyle: AIResponseStyle { didSet { defaults.set(responseStyle.rawValue, forKey: "ai_personal_style") } }

    // Computer mode permissions
    @Published public private(set) var allowedSources: Set<AIComputerSource>
    /// The user has seen Computer mode's permission screen.
    @Published public var computerConsentAnswered: Bool { didSet { defaults.set(computerConsentAnswered, forKey: "ai_computer_consent") } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = AIAssistantMode(rawValue: defaults.string(forKey: "ai_mode") ?? "") ?? .generic
        memoryEnabled = defaults.bool(forKey: "ai_memory_enabled")
        memoryConsentGiven = defaults.bool(forKey: "ai_memory_consent")
        preferredName = defaults.string(forKey: "ai_personal_name") ?? ""
        aboutMe = defaults.string(forKey: "ai_personal_about") ?? ""
        customInstructions = defaults.string(forKey: "ai_personal_instructions") ?? ""
        responseStyle = AIResponseStyle(rawValue: defaults.string(forKey: "ai_personal_style") ?? "") ?? .balanced
        allowedSources = Set((defaults.stringArray(forKey: "ai_computer_sources") ?? []).compactMap(AIComputerSource.init(rawValue:)))
        computerConsentAnswered = defaults.bool(forKey: "ai_computer_consent")
    }

    public func isAllowed(_ source: AIComputerSource) -> Bool { allowedSources.contains(source) }

    public func setAllowed(_ source: AIComputerSource, _ allowed: Bool) {
        if allowed { allowedSources.insert(source) } else { allowedSources.remove(source) }
        defaults.set(allowedSources.map(\.rawValue).sorted(), forKey: "ai_computer_sources")
        if allowed && source == .selectedText { Self.requestAccessibilityIfNeeded() }
    }

    /// Selected text from other apps can only be read with macOS Accessibility permission.
    /// This shows macOS's own prompt (once) if it hasn't been granted.
    @discardableResult
    public static func requestAccessibilityIfNeeded() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static var hasAccessibilityPermission: Bool { AXIsProcessTrusted() }

    /// The system instructions for the current mode (personal details only in Personal mode).
    /// Instructions that stay the same for the whole chat. Things that change every message
    /// (the time, what's on the Mac, memories) go with each message instead, so the chat
    /// session can keep its history between messages.
    public func modeInstructions() -> String {
        var lines = [
            "You are Master Dock AI, a friendly assistant built into a Mac dock app. You are chatting with one person.",
            "Talk to them directly as \"you\", like a helpful friend would. Never call them \"the user\" or talk about them in the third person.",
            "Sound warm, relaxed and human, not robotic. Write plain text with no markdown symbols like ** or #.",
            "Follow the whole conversation. Short follow ups like \"what about now?\" or \"and that one?\" are about what you were just discussing, so answer that.",
            "Never repeat one of your earlier replies, and don't ask something they already told you.",
            "Some messages come with background info in brackets. Use it only when it helps, and never read it back word for word."
        ]
        switch mode {
        case .generic:
            lines.append("Answer clearly and helpfully.")
        case .personal:
            let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { lines.append("Their name is \(name). Use it now and then, not in every message, and don't greet them again after the first message.") }
            let about = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
            if !about.isEmpty { lines.append("What they told you about themselves: \(about)") }
            lines.append(responseStyle.instruction)
            let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty { lines.append("How they want you to act: \(custom)") }
        case .computer:
            lines.append("The background info can include what's on their Mac right now. Mention it casually when it answers the question, for example \"looks like you're in Safari right now\".")
        }
        return lines.joined(separator: "\n")
    }

    /// The current date and time, sent with each message.
    public static func nowLine(_ now: Date = Date()) -> String {
        "It's \(dayFormatter.string(from: now)) right now."
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy, h:mm a"
        return f
    }()
}

// MARK: - Memory

/// Saved conversations on this Mac, so the AI can recall things from earlier days.
/// Both the user's messages and the AI's replies are kept.
public final class AIMemoryStore: ObservableObject {
    public static let shared = AIMemoryStore()

    public struct Exchange: Codable, Identifiable, Equatable, Sendable {
        public let id: UUID
        public let date: Date
        public let user: String
        public let assistant: String

        public init(id: UUID = UUID(), date: Date = Date(), user: String, assistant: String) {
            self.id = id
            self.date = date
            self.user = user
            self.assistant = assistant
        }
    }

    @Published public private(set) var exchanges: [Exchange] = []

    private let fileURL: URL
    private let maxExchanges = 2000

    public init(fileURL: URL? = nil) {
        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let folder = support.appendingPathComponent("MasterDock", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.fileURL = folder.appendingPathComponent("ai_memory.json")
        }
        load()
    }

    public func record(user: String, assistant: String, date: Date = Date()) {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = assistant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty, !a.isEmpty, !a.hasPrefix("⚠️") else { return }
        exchanges.append(Exchange(date: date, user: u, assistant: a))
        if exchanges.count > maxExchanges { exchanges.removeFirst(exchanges.count - maxExchanges) }
        save()
    }

    public func forgetAll() {
        exchanges.removeAll()
        save()
    }

    /// Past exchanges that share the most meaningful words with the question (newer wins ties).
    public func relevant(to query: String, limit: Int = 4, excludingAfter cutoff: Date? = nil) -> [Exchange] {
        let queryWords = Self.keywords(query)
        guard !queryWords.isEmpty else { return [] }
        let pool = exchanges.filter { cutoff == nil || $0.date < cutoff! }
        // Rare words count more than common ones.
        var documentFrequency: [String: Int] = [:]
        let docs = pool.map { Self.keywords($0.user + " " + $0.assistant) }
        for words in docs { for w in words { documentFrequency[w, default: 0] += 1 } }
        let total = Double(max(pool.count, 1))

        let scored: [(Exchange, Double)] = zip(pool, docs).compactMap { exchange, words in
            let userWords = Self.keywords(exchange.user)
            var score = 0.0
            for w in queryWords where words.contains(w) {
                let idf = log(1 + total / Double(documentFrequency[w] ?? 1))
                score += idf * (userWords.contains(w) ? 1.5 : 1.0)
            }
            return score > 0 ? (exchange, score) : nil
        }
        return scored
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.date > $1.0.date }
            .prefix(limit)
            .map { $0.0 }
            .sorted { $0.date < $1.date }
    }

    /// Text block given to the AI with the most relevant memories.
    public func contextBlock(for query: String, maxCharacters: Int = 1600) -> String {
        let found = relevant(to: query)
        guard !found.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        var block = "From your earlier chats with them (use these if they're asking about something from before):"
        for e in found {
            let entry = "\n[\(formatter.string(from: e.date))] They said: \(Self.clip(e.user, 300))\nYou replied: \(Self.clip(e.assistant, 450))"
            if block.count + entry.count > maxCharacters { break }
            block += entry
        }
        return block
    }

    public static func clip(_ text: String, _ limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit)) + "…"
    }

    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "is", "are", "was", "were", "be", "been", "to", "of", "in", "on",
        "for", "with", "at", "by", "it", "its", "this", "that", "these", "those", "i", "me", "my", "you", "your",
        "we", "our", "how", "what", "when", "where", "which", "who", "why", "do", "does", "did", "can", "could",
        "would", "should", "will", "much", "many", "about", "from", "as", "so", "if", "then", "than", "there",
        "here", "just", "like", "get", "got", "have", "has", "had", "not", "no", "yes", "ok", "okay", "please",
        "tell", "again", "remember", "said", "say", "earlier", "before", "last", "time", "day", "days", "ago"
    ]

    static func keywords(_ text: String) -> Set<String> {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopWords.contains($0) }
            .map { word -> String in
                // Light stemming so "houses" matches "house".
                if word.count > 4 && word.hasSuffix("es") { return String(word.dropLast(2)) }
                if word.count > 3 && word.hasSuffix("s") { return String(word.dropLast()) }
                return word
            }
        return Set(words)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([Exchange].self, from: data) else { return }
        exchanges = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(exchanges) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Reading the app you're in

/// Remembers the last app you used before the dock, and (with permission) reads its selected text.
public final class FrontmostAppTracker {
    public static let shared = FrontmostAppTracker()

    public private(set) var lastApp: NSRunningApplication?
    private var observer: NSObjectProtocol?

    public init() {
        let own = Bundle.main.bundleIdentifier
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != own { lastApp = current }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != own else { return }
            self?.lastApp = app
        }
    }

    /// "Safari: Apple Liquid Glass – Google Search"
    public func appDescription() -> String? {
        guard let app = lastApp else { return nil }
        let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown app"
        if AXIsProcessTrusted(), let title = focusedWindowTitle(of: app), !title.isEmpty {
            return "\(name): \(title)"
        }
        return name
    }

    /// Selected text in the last app. Returns nil without Accessibility permission.
    public func selectedText(limit: Int = 4000) -> String? {
        guard AXIsProcessTrusted(), let app = lastApp else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focusedElement = focused, CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else { return nil }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : AIMemoryStore.clip(trimmed, limit)
    }

    private func focusedWindowTitle(of app: NSRunningApplication) -> String? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let windowElement = window, CFGetTypeID(windowElement) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }
}
