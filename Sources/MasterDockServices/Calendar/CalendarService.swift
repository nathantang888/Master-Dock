import Foundation
import EventKit
import Combine
import SwiftUI
import MasterDockCore

public final class CalendarService: ObservableObject, CalendarServiceProtocol {
    public static let shared = CalendarService()
    
    @Published public private(set) var todayEvents: [CalendarMeeting] = []
    @Published public private(set) var accounts: [CalendarAccount] = []
    @Published public private(set) var isSyncing: Bool = false
    /// Google accounts signed in on this Mac (System Settings > Internet Accounts).
    @Published public private(set) var detectedSources: [DetectedCalendarSource] = []
    /// Whether Master Dock is allowed to read the Mac's calendars.
    @Published public private(set) var hasCalendarAccess: Bool = false
    
    private let eventStore = EKEventStore()
    private let accountsStorageKey: String
    private let customEventsStorageKey: String
    private let autoLinkMacCalendar: Bool
    
    /// Built-in account that shows events from the Mac Calendar app (iCloud, On My Mac, etc.).
    public static let macCalendarAccountID = "mac-calendar"
    private static let macCalendarDismissedKey = "masterdock_mac_calendar_dismissed"
    private static let dismissedSourcesKey = "masterdock_dismissed_calendar_sources"
    
    public init(
        accountsStorageKey: String = "masterdock_calendar_accounts_v2",
        customEventsStorageKey: String = "masterdock_custom_events_v1",
        autoRefresh: Bool = true
    ) {
        self.accountsStorageKey = accountsStorageKey
        self.customEventsStorageKey = customEventsStorageKey
        // Only the real app links the Mac Calendar automatically; tests build services with autoRefresh off.
        self.autoLinkMacCalendar = autoRefresh
        loadPersistedAccounts()
        if autoRefresh {
            Task {
                await refreshEvents()
            }
            observeCalendarChanges()
        }
    }
    
    private var changeObservers: [NSObjectProtocol] = []
    private var pendingRefresh: Task<Void, Never>?
    
    /// Refreshes automatically when an event is added or edited in the Calendar app, and when the
    /// day rolls over at midnight, instead of only at launch or when Refresh is pressed.
    private func observeCalendarChanges() {
        let center = NotificationCenter.default
        for name in [Notification.Name.EKEventStoreChanged, Notification.Name.NSCalendarDayChanged] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRefresh()
            }
            changeObservers.append(observer)
        }
    }
    
    /// EventKit can post several change notifications in a row; wait a moment and refresh once.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshEvents()
        }
    }
    
    deinit {
        changeObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - Account Management
    
    public func linkAccount(_ account: CalendarAccount) {
        // If adding a custom Google account, purge default-google-work placeholder
        if account.accountType == .googleCalendar && account.id != "default-google-work" {
            accounts.removeAll { $0.id == "default-google-work" }
        }
        // If adding a custom Apple account, purge default-apple-account placeholder
        if account.accountType == .appleCalendar && account.id != "default-apple-account" {
            accounts.removeAll { $0.id == "default-apple-account" }
        }
        
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
        } else {
            accounts.append(account)
        }
        persistAccounts()
        Task { @MainActor in
            await refreshEvents()
        }
    }
    
    public func unlinkAccount(id: String) {
        rememberMacCalendarDismissal(for: id)
        if let idx = accounts.firstIndex(where: { $0.id == id }) {
            accounts[idx].isLinked = false
            accounts[idx].isEnabled = false
            persistAccounts()
            Task { @MainActor in
                await refreshEvents()
            }
        }
    }
    
    public func toggleAccountEnabled(id: String) {
        if let idx = accounts.firstIndex(where: { $0.id == id }) {
            accounts[idx].isEnabled.toggle()
            persistAccounts()
            Task { @MainActor in
                await refreshEvents()
            }
        }
    }
    
    public func updateAccount(_ account: CalendarAccount) {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx] = account
            persistAccounts()
            Task { @MainActor in
                await refreshEvents()
            }
        }
    }
    
    public func removeAccount(id: String) {
        rememberMacCalendarDismissal(for: id)
        accounts.removeAll { $0.id == id }
        persistAccounts()
        Task { @MainActor in
            await refreshEvents()
        }
    }
    
    public func updateAccountICS(id: String, icsURL: String?) {
        if let idx = accounts.firstIndex(where: { $0.id == id }) {
            let trimmed = icsURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            accounts[idx].icsURL = (trimmed?.isEmpty == true) ? nil : trimmed
            persistAccounts()
            Task { @MainActor in
                await refreshEvents()
            }
        }
    }
    
    /// If the user removes the built-in Mac Calendar account, don't add it back on the next refresh.
    private func rememberMacCalendarDismissal(for id: String) {
        if id == Self.macCalendarAccountID {
            UserDefaults.standard.set(true, forKey: Self.macCalendarDismissedKey)
        }
        // Same for Google accounts that were linked from this Mac.
        if let sourceID = accounts.first(where: { $0.id == id })?.eventKitSourceID {
            var dismissed = dismissedSourceIDs
            dismissed.insert(sourceID)
            dismissedSourceIDs = dismissed
        }
    }
    
    // MARK: - Saving events to your real calendars

    /// A calendar on this Mac that new events can be saved to.
    public struct WritableCalendar: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        public let accountID: String
        public let accountName: String
        public let isGoogle: Bool
        public let colorHex: String?
        public let isDefault: Bool

        public var displayName: String { title == accountName ? title : "\(accountName) • \(title)" }
    }

    public enum CalendarWriteError: LocalizedError {
        case noAccess, calendarMissing

        public var errorDescription: String? {
            switch self {
            case .noAccess: return "Master Dock needs Calendar access to save events. Turn it on in System Settings > Privacy & Security > Calendars."
            case .calendarMissing: return "That calendar isn't available anymore. Pick another one."
            }
        }
    }

    /// Calendars you can add events to, grouped under the dock's accounts (Google ones first).
    public func writableCalendars() -> [WritableCalendar] {
        guard hasCalendarAccess else { return [] }
        let sources = eventStore.sources.filter { !$0.calendars(for: .event).isEmpty }
        let active = accounts.filter { $0.isLinked && $0.isEnabled }
        let googleCount = max(1, active.filter { $0.accountType == .googleCalendar }.count)

        var googleSourceIDs = Set(sources.filter { Self.isGoogleStyleAccount($0) }.map { $0.sourceIdentifier })
        for account in accounts where account.accountType == .googleCalendar {
            googleSourceIDs.formUnion(matchingSourceIDs(for: account, in: sources, googleAccountCount: googleCount))
        }
        let defaultID = eventStore.defaultCalendarForNewEvents?.calendarIdentifier

        var result: [WritableCalendar] = []
        var seen = Set<String>()
        for account in active.sorted(by: { ($0.accountType == .googleCalendar ? 0 : 1) < ($1.accountType == .googleCalendar ? 0 : 1) }) {
            let calendars: [EKCalendar]
            switch account.accountType {
            case .googleCalendar:
                let ids = matchingSourceIDs(for: account, in: sources, googleAccountCount: googleCount)
                calendars = sources.filter { ids.contains($0.sourceIdentifier) }.flatMap { $0.calendars(for: .event) }
            case .appleCalendar:
                calendars = sources.filter { !googleSourceIDs.contains($0.sourceIdentifier) }.flatMap { $0.calendars(for: .event) }
            }
            let usable = calendars
                .filter { $0.allowsContentModifications && $0.type != .birthday && $0.type != .subscription }
                .sorted { a, b in
                    // The main calendar (named after the account's email) goes first.
                    let aMain = a.title.contains("@"), bMain = b.title.contains("@")
                    if aMain != bMain { return aMain }
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            for cal in usable where !seen.contains(cal.calendarIdentifier) {
                seen.insert(cal.calendarIdentifier)
                result.append(WritableCalendar(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    accountID: account.id,
                    accountName: account.name,
                    isGoogle: account.accountType == .googleCalendar,
                    colorHex: Self.hex(for: cal.cgColor),
                    isDefault: cal.calendarIdentifier == defaultID
                ))
            }
        }
        return result
    }

    /// Saves a real event to a calendar on this Mac. Google calendars sync it to Google
    /// within a few seconds, so it shows up on your phone and calendar.google.com too.
    public func saveEvent(toCalendar calendarID: String, title: String, startDate: Date, endDate: Date,
                          isAllDay: Bool, location: String?, meetingURL: URL?) throws {
        guard hasCalendarAccess else { throw CalendarWriteError.noAccess }
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { throw CalendarWriteError.calendarMissing }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.isAllDay = isAllDay
        event.startDate = startDate
        event.endDate = endDate > startDate ? endDate : startDate.addingTimeInterval(isAllDay ? 0 : 3600)

        let place = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let meetingURL {
            event.url = meetingURL
            event.notes = "Join the meeting: \(meetingURL.absoluteString)"
            // Google Calendar shows the location as a clickable link, so put the meeting there
            // unless there's a real place.
            event.location = (place.isEmpty || place == meetingURL.absoluteString) ? meetingURL.absoluteString : place
        } else if !place.isEmpty {
            event.location = place
        }

        try eventStore.save(event, span: .thisEvent, commit: true)
        Task { @MainActor in
            await refreshEvents()
        }
    }

    private static func hex(for color: CGColor?) -> String? {
        guard let color, let rgb = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = rgb.components, c.count >= 3 else { return nil }
        return String(format: "#%02X%02X%02X", Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255))
    }

    // MARK: - Custom User-Created Events
    
    public func addCustomEvent(to accountID: String, title: String, startDate: Date, endDate: Date, location: String? = nil, joinURL: URL? = nil, isAllDay: Bool = false) {
        var existing = PersistenceController.shared.load([SavedCustomCalendarEvent].self, forKey: customEventsStorageKey) ?? []
        let newEvent = SavedCustomCalendarEvent(
            accountID: accountID,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            joinURLString: joinURL?.absoluteString,
            isAllDay: isAllDay
        )
        existing.append(newEvent)
        PersistenceController.shared.save(existing, forKey: customEventsStorageKey)
        Task { @MainActor in
            await refreshEvents()
        }
    }
    
    public func removeCustomEvent(id: String) {
        var existing = PersistenceController.shared.load([SavedCustomCalendarEvent].self, forKey: customEventsStorageKey) ?? []
        existing.removeAll { $0.id == id }
        PersistenceController.shared.save(existing, forKey: customEventsStorageKey)
        Task { @MainActor in
            await refreshEvents()
        }
    }
    
    private func loadCustomEvents(for accountID: String, date: Date = Date()) -> [CalendarMeeting] {
        guard let saved = PersistenceController.shared.load([SavedCustomCalendarEvent].self, forKey: customEventsStorageKey) else {
            return []
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        let account = accounts.first(where: { $0.id == accountID })
        
        return saved.filter { $0.accountID == accountID && $0.endDate > startOfDay && $0.startDate < endOfDay }.map { savedEvent in
            CalendarMeeting(
                id: savedEvent.id,
                title: savedEvent.title,
                startDate: savedEvent.startDate,
                endDate: savedEvent.endDate,
                location: savedEvent.location,
                joinURL: savedEvent.joinURLString != nil ? URL(string: savedEvent.joinURLString!) : nil,
                isAllDay: savedEvent.isAllDay,
                accountID: accountID,
                accountName: account?.name ?? "Calendar",
                accountType: account?.accountType,
                calendarName: account?.name
            )
        }
    }
    
    // MARK: - Multi-Account Event Refresh & Aggregation
    
    @MainActor
    public func refreshEvents() async {
        isSyncing = true
        defer { isSyncing = false }

        // Auto-purge default placeholder if any custom account exists
        if accounts.contains(where: { $0.accountType == .googleCalendar && $0.id != "default-google-work" }) {
            accounts.removeAll { $0.id == "default-google-work" }
        }
        if accounts.contains(where: { $0.accountType == .appleCalendar && $0.id != "default-apple-account" }) {
            accounts.removeAll { $0.id == "default-apple-account" }
        }

        var status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            if #available(macOS 14.0, *) {
                do {
                    _ = try await eventStore.requestFullAccessToEvents()
                } catch {}
            } else {
                _ = await withCheckedContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                }
            }
            status = EKEventStore.authorizationStatus(for: .event)
            // A store created before access was granted needs a nudge to see the accounts.
            eventStore.refreshSourcesIfNecessary()
        }

        // Write-only access can add events but cannot read them, so it does not count here.
        let hasEventKitAccess: Bool
        if #available(macOS 14.0, *) {
            hasEventKitAccess = (status == .fullAccess)
        } else {
            hasEventKitAccess = (status == .authorized)
        }
        self.hasCalendarAccess = hasEventKitAccess

        // Find every calendar account set up on this Mac (iCloud, each Google account, etc.)
        let eventSources: [EKSource] = hasEventKitAccess
            ? eventStore.sources.filter { !$0.calendars(for: .event).isEmpty }
            : []

        // Events in the Mac Calendar app (iCloud, On My Mac...) used to be ignored unless the user
        // had manually added an Apple Calendar account. Link it automatically once access is granted.
        if autoLinkMacCalendar
            && hasEventKitAccess
            && !accounts.contains(where: { $0.accountType == .appleCalendar })
            && !UserDefaults.standard.bool(forKey: Self.macCalendarDismissedKey) {
            accounts.append(CalendarAccount(
                id: Self.macCalendarAccountID,
                name: "Mac Calendar",
                accountType: .appleCalendar,
                emailOrUsername: "This Mac"
            ))
        }

        // Connect Google accounts that are signed in on this Mac, one Master Dock account each.
        attachGoogleSources(eventSources)

        let activeAccounts = accounts.filter { $0.isLinked && $0.isEnabled }
        guard !activeAccounts.isEmpty else {
            self.todayEvents = []
            persistAccounts()
            return
        }

        var aggregatedEvents: [CalendarMeeting] = []

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        // Query system EventKit store once if authorized
        var rawEventKitEvents: [EKEvent] = []
        if hasEventKitAccess {
            let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
            rawEventKitEvents = eventStore.events(matching: predicate)
        }

        // Google accounts on this Mac show under their own Google account (or are hidden if the user
        // turned that account off), so the Mac Calendar account skips them instead of showing them twice.
        let activeGoogleAccounts = activeAccounts.filter { $0.accountType == .googleCalendar }
        var googleSourceIDs = Set(eventSources.filter { Self.isGoogleStyleAccount($0) }.map { $0.sourceIdentifier })
        for account in accounts where account.accountType == .googleCalendar {
            googleSourceIDs.formUnion(matchingSourceIDs(for: account, in: eventSources, googleAccountCount: max(1, activeGoogleAccounts.count)))
        }

        for (index, account) in accounts.enumerated() {
            guard account.isLinked && account.isEnabled else {
                continue
            }

            var accountMeetings: [CalendarMeeting] = []

            switch account.accountType {
            case .appleCalendar:
                let appleEvents = rawEventKitEvents.filter { !googleSourceIDs.contains($0.calendar.source.sourceIdentifier) }
                accountMeetings = appleEvents.map { makeMeeting(from: $0, account: account) }

                // Only provide sample events if explicitly a demo calendar
                if accountMeetings.isEmpty && account.id == "demo-calendar" {
                    accountMeetings = generateSampleEvents(for: account)
                }

            case .googleCalendar:
                // 1. Google account signed in on this Mac: instant, no network request needed.
                let sourceIDs = matchingSourceIDs(for: account, in: eventSources, googleAccountCount: activeGoogleAccounts.count)
                if !sourceIDs.isEmpty {
                    accountMeetings = rawEventKitEvents
                        .filter { sourceIDs.contains($0.calendar.source.sourceIdentifier) }
                        .map { makeMeeting(from: $0, account: account) }
                }

                // 2. Secret iCal feed URL pasted by the user.
                if accountMeetings.isEmpty, sourceIDs.isEmpty,
                   let urlStr = account.icsURL?.trimmingCharacters(in: .whitespacesAndNewlines), !urlStr.isEmpty,
                   let url = URL(string: urlStr),
                   let icsData = await fetchICS(from: url) {
                    accountMeetings = ICalendarParser.parse(icsContent: icsData, account: account, forDay: Date())
                }

                // 3. Last resort: the calendar may be public.
                if accountMeetings.isEmpty, sourceIDs.isEmpty, account.icsURL == nil,
                   account.emailOrUsername.contains("@") {
                    let cleanedEmail = account.emailOrUsername.trimmingCharacters(in: .whitespaces)
                    if let encodedEmail = cleanedEmail.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                       let probeURL = URL(string: "https://calendar.google.com/calendar/ical/\(encodedEmail)/public/basic.ics"),
                       let icsData = await fetchICS(from: probeURL) {
                        accountMeetings = ICalendarParser.parse(icsContent: icsData, account: account, forDay: Date())
                    }
                }

                // Only provide sample events if explicitly a demo calendar
                if accountMeetings.isEmpty && account.id == "demo-calendar" {
                    accountMeetings = generateSampleEvents(for: account)
                }
            }

            // Merge custom user-added events for this account
            let customItems = loadCustomEvents(for: account.id, date: Date())
            accountMeetings.append(contentsOf: customItems)

            // Update account event count and sync time
            accounts[index].eventCount = accountMeetings.count
            accounts[index].lastSyncedAt = Date()

            aggregatedEvents.append(contentsOf: accountMeetings)
        }

        // Deduplicate events by accountID, title, and start time
        var seenKeys = Set<String>()
        var uniqueEvents: [CalendarMeeting] = []
        for event in aggregatedEvents {
            let key = "\(event.accountID ?? "")_\(event.title)_\(Int(event.startDate.timeIntervalSince1970))"
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                uniqueEvents.append(event)
            }
        }

        // Sort chronologically
        self.todayEvents = uniqueEvents.sorted { $0.startDate < $1.startDate }
        persistAccounts()
    }

    // MARK: - Accounts signed in on this Mac
    
    /// One line per calendar account on this Mac, for the test runner's diagnostics output.
    public func macSourceDiagnostics() -> [String] {
        return eventStore.sources.map { source in
            let calendars = source.calendars(for: .event).map { $0.title }.sorted()
            return "\(source.title) [type \(source.sourceType.rawValue)] google=\(Self.isGoogleStyleAccount(source)) email=\(Self.accountEmail(for: source)) calendars=\(calendars)"
        }
    }

    /// Builds the "Found on this Mac" list and links Google accounts that aren't linked yet.
    @MainActor
    private func attachGoogleSources(_ sources: [EKSource]) {
        let dismissed = dismissedSourceIDs
        var detected: [DetectedCalendarSource] = []

        for source in sources where Self.isGoogleStyleAccount(source) {
            let email = Self.accountEmail(for: source)
            let emailLower = email.lowercased()

            // Match an existing account by its saved Mac source, or by the same email address.
            var linkedIndex = accounts.firstIndex { $0.eventKitSourceID == source.sourceIdentifier }
            if linkedIndex == nil {
                linkedIndex = accounts.firstIndex {
                    $0.accountType == .googleCalendar
                        && $0.eventKitSourceID == nil
                        && $0.emailOrUsername.lowercased().trimmingCharacters(in: .whitespaces) == emailLower
                }
                if let idx = linkedIndex {
                    accounts[idx].eventKitSourceID = source.sourceIdentifier
                }
            }

            if linkedIndex == nil && autoLinkMacCalendar && !dismissed.contains(source.sourceIdentifier) {
                accounts.append(Self.makeGoogleAccount(for: source))
                linkedIndex = accounts.count - 1
            }

            detected.append(DetectedCalendarSource(
                id: source.sourceIdentifier,
                email: email,
                calendarCount: source.calendars(for: .event).count,
                linkedAccountID: linkedIndex.map { accounts[$0].id }
            ))
        }

        self.detectedSources = detected.sorted { $0.email.lowercased() < $1.email.lowercased() }
    }

    /// Links a Google account from the "Found on this Mac" list.
    public func linkDetectedSource(id: String) {
        var dismissed = dismissedSourceIDs
        dismissed.remove(id)
        dismissedSourceIDs = dismissed

        guard !accounts.contains(where: { $0.eventKitSourceID == id }),
              let source = eventStore.sources.first(where: { $0.sourceIdentifier == id }) else { return }
        linkAccount(Self.makeGoogleAccount(for: source))
    }

    /// Which Mac calendar accounts feed this Google account.
    private func matchingSourceIDs(for account: CalendarAccount, in sources: [EKSource], googleAccountCount: Int) -> Set<String> {
        guard account.accountType == .googleCalendar else { return [] }

        if let sourceID = account.eventKitSourceID {
            return sources.contains { $0.sourceIdentifier == sourceID } ? [sourceID] : []
        }

        let email = account.emailOrUsername.lowercased().trimmingCharacters(in: .whitespaces)
        if !email.isEmpty {
            let byEmail = sources.filter { source in
                Self.isGoogleStyleAccount(source) && (source.title.lowercased() == email
                    || Self.accountEmail(for: source).lowercased() == email
                    || source.calendars(for: .event).contains { $0.title.lowercased() == email })
            }
            if !byEmail.isEmpty {
                return Set(byEmail.map { $0.sourceIdentifier })
            }
        }

        // Older setups with a single Google account and no matching email: use any Google source.
        guard googleAccountCount == 1 else { return [] }
        return Set(sources.filter { source in
            let title = source.title.lowercased()
            return title.contains("google") || title.contains("gmail")
        }.map { $0.sourceIdentifier })
    }

    /// Google (and Google Workspace school or work) accounts show up in the Calendar app as CalDAV
    /// accounts named after their email address. iCloud, On My Mac and subscriptions are excluded.
    private static func isGoogleStyleAccount(_ source: EKSource) -> Bool {
        switch source.sourceType {
        case .local, .subscribed, .birthdays, .mobileMe:
            return false
        default:
            break
        }
        let title = source.title.lowercased()
        if title.contains("icloud") || title.contains("on my mac") { return false }
        if title.contains("@") || title.contains("google") || title.contains("gmail") { return true }
        // Some Macs name the account just "Google" or a custom label; the main calendar is still
        // named after the account's email address.
        return source.calendars(for: .event).contains { $0.title.contains("@") }
    }
    
    /// The account's email: the source title when it is an email, otherwise the calendar named
    /// after an email address (Google names the main calendar after the account).
    static func accountEmail(for source: EKSource) -> String {
        let title = source.title.trimmingCharacters(in: .whitespaces)
        if title.contains("@") { return title }
        let emailCalendar = source.calendars(for: .event)
            .map { $0.title.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("@") }
            .sorted()
            .first
        return emailCalendar ?? title
    }
    
    private static func makeGoogleAccount(for source: EKSource) -> CalendarAccount {
        let email = accountEmail(for: source)
        return CalendarAccount(
            name: email,
            accountType: .googleCalendar,
            emailOrUsername: email,
            eventKitSourceID: source.sourceIdentifier
        )
    }

    private func makeMeeting(from ekEvent: EKEvent, account: CalendarAccount) -> CalendarMeeting {
        // Join button only for real meeting links (from the notes, location or the event's URL).
        let joinURL = ICalendarParser.extractMeetingURL(from: "\(ekEvent.notes ?? "") \(ekEvent.location ?? "")")
            ?? ekEvent.url.flatMap { ICalendarParser.isMeetingURL($0) ? $0 : nil }
        return CalendarMeeting(
            id: ekEvent.eventIdentifier ?? UUID().uuidString,
            title: ekEvent.title ?? "Untitled Event",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            location: ekEvent.location,
            joinURL: joinURL,
            isAllDay: ekEvent.isAllDay,
            accountID: account.id,
            accountName: account.name,
            accountType: account.accountType,
            calendarName: ekEvent.calendar.title
        )
    }

    /// Mac accounts the user removed from Master Dock, so they are not linked again automatically.
    private var dismissedSourceIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.dismissedSourcesKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.dismissedSourcesKey) }
    }

    private func fetchICS(from url: URL) async -> String? {
        var targetURL = url
        if url.scheme?.lowercased() == "webcal" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.scheme = "https"
            if let converted = components?.url {
                targetURL = converted
            }
        }
        
        var request = URLRequest(url: targetURL)
        request.timeoutInterval = 15.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/calendar, text/plain, */*", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    // MARK: - Sample Events Generator (Contextualized by Account)
    
    private func generateSampleEvents(for account: CalendarAccount) -> [CalendarMeeting] {
        let calendar = Calendar.current
        let now = Date()
        
        switch account.accountType {
        case .appleCalendar:
            let start1 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
            let end1 = calendar.date(bySettingHour: 10, minute: 45, second: 0, of: now) ?? now
            
            let start2 = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: now) ?? now
            let end2 = calendar.date(bySettingHour: 16, minute: 30, second: 0, of: now) ?? now
            
            return [
                CalendarMeeting(
                    id: "apple-\(account.id)-1",
                    title: "\(account.name) Architecture & Liquid Glass Sync",
                    startDate: start1,
                    endDate: end1,
                    location: "Cupertino Conference Rm 3",
                    joinURL: URL(string: "https://zoom.us/j/9876543210"),
                    isAllDay: false,
                    accountID: account.id,
                    accountName: account.name,
                    accountType: .appleCalendar,
                    calendarName: "Work"
                ),
                CalendarMeeting(
                    id: "apple-\(account.id)-2",
                    title: "\(account.name) Design Review",
                    startDate: start2,
                    endDate: end2,
                    location: "Design Studio",
                    joinURL: nil,
                    isAllDay: false,
                    accountID: account.id,
                    accountName: account.name,
                    accountType: .appleCalendar,
                    calendarName: "Personal"
                )
            ]
            
        case .googleCalendar:
            let displayName = account.name.isEmpty ? "Google Calendar" : account.name
            
            let start1 = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: now) ?? now
            let end1 = calendar.date(bySettingHour: 10, minute: 15, second: 0, of: now) ?? now
            
            let start2 = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: now) ?? now
            let end2 = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: now) ?? now
            
            let start3 = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now) ?? now
            let end3 = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now
            
            return [
                CalendarMeeting(
                    id: "google-\(account.id)-1",
                    title: "\(displayName) Morning Standup & Priorities",
                    startDate: start1,
                    endDate: end1,
                    location: "Google Meet Video Call",
                    joinURL: URL(string: "https://meet.google.com/abc-defg-hij"),
                    isAllDay: false,
                    accountID: account.id,
                    accountName: account.name,
                    accountType: .googleCalendar,
                    calendarName: "Primary"
                ),
                CalendarMeeting(
                    id: "google-\(account.id)-2",
                    title: "\(displayName) Architecture & Product Review",
                    startDate: start2,
                    endDate: end2,
                    location: "Google Meet",
                    joinURL: URL(string: "https://meet.google.com/klm-nopq-rst"),
                    isAllDay: false,
                    accountID: account.id,
                    accountName: account.name,
                    accountType: .googleCalendar,
                    calendarName: "Work"
                ),
                CalendarMeeting(
                    id: "google-\(account.id)-3",
                    title: "\(displayName) Team Sync & Wrap-up",
                    startDate: start3,
                    endDate: end3,
                    location: "Google Meet",
                    joinURL: URL(string: "https://meet.google.com/uvw-xyza-bcd"),
                    isAllDay: false,
                    accountID: account.id,
                    accountName: account.name,
                    accountType: .googleCalendar,
                    calendarName: "Work"
                )
            ]
        }
    }
    
    // MARK: - Persistence
    
    private func loadPersistedAccounts() {
        if let loaded = PersistenceController.shared.load([CalendarAccount].self, forKey: accountsStorageKey), !loaded.isEmpty {
            var sanitized = loaded
            // Purge default-google-work placeholder
            sanitized.removeAll { $0.id == "default-google-work" }
            sanitized.removeAll { $0.id == "default-apple-account" }
            self.accounts = sanitized
            persistAccounts()
        } else {
            self.accounts = []
            persistAccounts()
        }
    }
    
    private func persistAccounts() {
        PersistenceController.shared.save(self.accounts, forKey: accountsStorageKey)
    }
}
