import SwiftUI
import MasterDockCore
import MasterDockServices

public struct WidgetDrawerSectionView: View {
    @ObservedObject public var statsService: SystemStatsService
    @ObservedObject public var weatherService: WeatherService
    
    public init(statsService: SystemStatsService, weatherService: WeatherService) {
        self.statsService = statsService
        self.weatherService = weatherService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Widget Drawer & Health",
                iconSystemName: "rectangle.3.group.fill"
            )
            
            HStack(spacing: 8) {
                // Live Clock & Date
                VStack(alignment: .leading, spacing: 2) {
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        Text(context.date.formatted(date: .omitted, time: .standard))
                            .font(AppTypography.titleMedium.monospacedDigit())
                            .foregroundColor(.white)
                        
                        Text(context.date.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .liquidPillStyle(cornerRadius: 12)
                
                // Weather Widget
                HStack(spacing: 8) {
                    Image(systemName: weatherService.currentWeather.iconSystemName)
                        .font(.system(size: 20))
                        .foregroundColor(GlassTheme.accentAmber)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weatherService.currentWeather.condition == "Loading" ? "--°" : "\(weatherService.currentWeather.temperature)°")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(.white)
                        Text(weatherService.currentWeather.condition)
                            .font(AppTypography.micro)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .liquidPillStyle(cornerRadius: 12)
            }
            
            // System Stats Triple Ring / Meter Card
            HStack(spacing: 12) {
                StatMeter(
                    title: "CPU",
                    percentage: statsService.cpuUsage,
                    color: GlassTheme.accentCyan
                )
                
                StatMeter(
                    title: "RAM",
                    percentage: statsService.memoryUsage,
                    color: GlassTheme.accentPurple
                )
                
                StatMeter(
                    title: "Disk",
                    percentage: statsService.diskUsage,
                    color: GlassTheme.accentEmerald
                )
            }
            .padding(10)
            .liquidPillStyle(cornerRadius: 12)
        }
    }
}

private struct StatMeter: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 3.5)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, percentage / 100.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.75))
                Text("\(Int(percentage))%")
                    .font(AppTypography.monoNumber)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct CalendarSectionView: View {
    @ObservedObject public var calendarService: CalendarService
    @State private var selectedAccountID: String? = nil
    @State private var isShowingAccountSheet: Bool = false
    @State private var isShowingAddEventSheet: Bool = false
    
    public init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }
    
    private var activeAccounts: [CalendarAccount] {
        calendarService.accounts.filter { $0.isLinked && $0.isEnabled }
    }
    
    private var filteredEvents: [CalendarMeeting] {
        if let accountID = selectedAccountID {
            return calendarService.todayEvents.filter { $0.accountID == accountID }
        }
        return calendarService.todayEvents
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(
                    title: "Todays Events",
                    iconSystemName: "calendar",
                    count: calendarService.todayEvents.count,
                    actionTitle: calendarService.isSyncing ? "Syncing..." : "Refresh",
                    onAction: {
                        Task {
                            await calendarService.refreshEvents()
                        }
                    }
                )
                
                Spacer()
                
                HStack(spacing: 6) {
                    if !activeAccounts.isEmpty {
                        Button(action: { isShowingAddEventSheet = true }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Event")
                                    .font(AppTypography.micro)
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                        }
                        .buttonStyle(.pressable)
                        .help("Add a custom event for today")
                    }
                    
                    Button(action: { isShowingAccountSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 11))
                            Text("Accounts")
                                .font(AppTypography.micro)
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.pressable)
                    .help("Manage Linked Google & Apple Calendar Accounts")
                }
            }
            
            // Dynamic Filter Pills if multiple accounts exist
            if activeAccounts.count > 1 {
                HStack(spacing: 6) {
                    FilterChip(
                        title: "All",
                        count: calendarService.todayEvents.count,
                        isSelected: selectedAccountID == nil,
                        color: GlassTheme.accentCyan
                    ) {
                        selectedAccountID = nil
                    }
                    
                    ForEach(activeAccounts) { account in
                        let count = calendarService.todayEvents.filter { $0.accountID == account.id }.count
                        FilterChip(
                            title: account.name,
                            count: count,
                            isSelected: selectedAccountID == account.id,
                            color: account.accountType.brandAccentColor,
                            iconName: account.accountType.iconName
                        ) {
                            if selectedAccountID == account.id {
                                selectedAccountID = nil
                            } else {
                                selectedAccountID = account.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            
            if activeAccounts.isEmpty {
                VStack(spacing: 8) {
                    Text("No calendar accounts currently linked or enabled.")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.65))
                    
                    Button("Link Calendar Account") {
                        isShowingAccountSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if filteredEvents.isEmpty {
                let currentAccount = activeAccounts.first(where: { $0.id == selectedAccountID }) ?? activeAccounts.first
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 13))
                            .foregroundColor(GlassTheme.accentCyan)
                        Text(selectedAccountID == nil ? "No events scheduled for today" : "No events for today on \(currentAccount?.name ?? "this calendar")")
                            .font(AppTypography.captionBold)
                            .foregroundColor(.white)
                    }
                    
                    if let googleAcc = (currentAccount?.accountType == .googleCalendar ? currentAccount : activeAccounts.first(where: { $0.accountType == .googleCalendar })), googleAcc.icsURL == nil, googleAcc.eventKitSourceID == nil {
                        VStack(spacing: 6) {
                            Text("To sync live events from Google Calendar, paste your Secret iCal URL:")
                                .font(AppTypography.micro)
                                .foregroundColor(.white.opacity(0.70))
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 8) {
                                Button("Paste Secret iCal URL") {
                                    isShowingAccountSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button(action: {
                                    if let url = URL(string: "https://calendar.google.com/calendar/u/0/r/settings") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Text("Open Google Settings")
                                        Image(systemName: "arrow.up.right")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .liquidPillStyle(cornerRadius: 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(filteredEvents) { meeting in
                        MeetingCard(meeting: meeting)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAccountSheet) {
            CalendarAccountQuickSheet(calendarService: calendarService, isPresented: $isShowingAccountSheet)
        }
        .sheet(isPresented: $isShowingAddEventSheet) {
            AddCalendarEventQuickSheet(calendarService: calendarService, isPresented: $isShowingAddEventSheet)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    var iconName: String? = nil
    let onSelect: () -> Void
    
    private var textColor: Color {
        isSelected ? Color.white : Color.white.opacity(0.75)
    }
    
    private var countColor: Color {
        isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.5)
    }
    
    private var pillBackground: Color {
        isSelected ? color.opacity(0.85) : Color.white.opacity(0.06)
    }
    
    private var pillBorder: Color {
        isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.12)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                if let icon = iconName {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isSelected ? Color.white : color)
                }
                Text(title)
                    .font(AppTypography.captionBold)
                    .foregroundColor(textColor)
                
                Text("\(count)")
                    .font(AppTypography.micro)
                    .foregroundColor(countColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(isSelected ? 0.25 : 0.08)))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(pillBackground))
            .overlay(Capsule().strokeBorder(pillBorder, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
    }
}

private struct CalendarAccountQuickSheet: View {
    @ObservedObject var calendarService: CalendarService
    @Binding var isPresented: Bool
    @State private var isAddingNew = false
    @State private var newType: CalendarAccountType = .googleCalendar
    @State private var newName = ""
    @State private var newEmail = ""
    @State private var newICS = ""
    @State private var editingAccountID: String? = nil
    @State private var renamingAccountID: String? = nil
    @State private var renameText: String = ""
    @FocusState private var isRenameFieldFocused: Bool
    @State private var editingICS: String = ""
    
    /// The sheet opens inside the dock, so it must not be wider than the dock itself.
    private var sheetWidth: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "dock_width")
        let dockWidth = (saved >= 240 && saved <= 600) ? CGFloat(saved) : 340
        return min(400, dockWidth - 12)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 15))
                        .foregroundColor(GlassTheme.accentCyan)
                    Text("Linked Calendars")
                        .font(AppTypography.titleMedium)
                }
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            // Google Calendar helper banner
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(GlassTheme.accentCyan)
                Text("Link Apple and as many Google accounts as you want. They all show together.")
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Button(action: {
                    if let url = URL(string: "https://calendar.google.com/calendar/u/0/r/settings") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 3) {
                        Text("Google Settings")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(AppTypography.micro)
                    .foregroundColor(GlassTheme.accentCyan)
                }
                .buttonStyle(.pressable)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
            
            MacGoogleAccountsSection(calendarService: calendarService)
            
            if isAddingNew {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Link New Account")
                        .font(AppTypography.bodyBold)
                    
                    Picker("Service", selection: $newType) {
                        ForEach(CalendarAccountType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField(newType == .googleCalendar ? "Name (e.g. Work Google Calendar)" : "Name (e.g. Personal Apple Calendar)", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField(newType == .googleCalendar ? "Google Email (e.g. alex@gmail.com)" : "Apple ID / Email", text: $newEmail)
                        .textFieldStyle(.roundedBorder)
                    
                    if newType == .googleCalendar {
                        VStack(alignment: .leading, spacing: 3) {
                            TextField("Optional Google Calendar Secret iCal (.ics) URL", text: $newICS)
                                .textFieldStyle(.roundedBorder)
                            Text("Copy from Google Calendar: Settings > Integrate calendar > Secret address in iCal format.")
                                .font(AppTypography.micro)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            withAnimation { isAddingNew = false }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        Button("Link Account") {
                            let title = newName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? "\(newType.rawValue) (\(newEmail.isEmpty ? "Account" : newEmail))"
                                : newName.trimmingCharacters(in: .whitespaces)
                            let acc = CalendarAccount(
                                name: title,
                                accountType: newType,
                                emailOrUsername: newEmail.trimmingCharacters(in: .whitespaces),
                                isLinked: true,
                                isEnabled: true,
                                icsURL: newICS.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newICS.trimmingCharacters(in: .whitespaces)
                            )
                            calendarService.linkAccount(acc)
                            withAnimation { isAddingNew = false }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
            } else {
                Button(action: {
                    newName = ""
                    newEmail = ""
                    newICS = ""
                    withAnimation { isAddingNew = true }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Link New Google or Apple Calendar")
                    }
                    .font(AppTypography.captionBold)
                    .foregroundColor(GlassTheme.accentCyan)
                }
                .buttonStyle(.pressable)
            }
            
            ScrollView {
            VStack(spacing: 8) {
                ForEach(calendarService.accounts) { account in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: account.accountType.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(account.accountType.brandAccentColor)
                                .frame(width: 18)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    if renamingAccountID == account.id {
                                        TextField("Calendar name", text: $renameText)
                                            .textFieldStyle(.roundedBorder)
                                            .font(AppTypography.caption)
                                            .focused($isRenameFieldFocused)
                                            .onSubmit { saveRename(for: account) }
                                            .onExitCommand { renamingAccountID = nil }
                                        Button(action: { saveRename(for: account) }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 13))
                                                .foregroundColor(GlassTheme.accentEmerald)
                                        }
                                        .buttonStyle(.pressable)
                                        .help("Save name")
                                    } else {
                                        Text(account.name)
                                            .font(AppTypography.captionBold)
                                            .lineLimit(1)
                                            .onTapGesture(count: 2) { startRename(for: account) }
                                        Button(action: { startRename(for: account) }) {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.pressable)
                                        .help("Rename this calendar")
                                    }
                                    if renamingAccountID != account.id && account.eventKitSourceID != nil {
                                        Text("Synced from Mac")
                                            .font(AppTypography.micro)
                                            .foregroundColor(GlassTheme.accentCyan)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(GlassTheme.accentCyan.opacity(0.15)))
                                    } else if account.icsURL != nil {
                                        Text("iCal Live")
                                            .font(AppTypography.micro)
                                            .foregroundColor(GlassTheme.accentEmerald)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(GlassTheme.accentEmerald.opacity(0.15)))
                                    }
                                }
                                
                                HStack(spacing: 6) {
                                    Text(account.emailOrUsername.isEmpty ? account.accountType.rawValue : account.emailOrUsername)
                                        .font(AppTypography.micro)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(AppTypography.micro)
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("\(account.eventCount) events today")
                                        .font(AppTypography.micro)
                                        .foregroundColor(account.isEnabled ? GlassTheme.accentEmerald : .secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if account.accountType == .googleCalendar && account.eventKitSourceID == nil {
                                Button(action: {
                                    if editingAccountID == account.id {
                                        editingAccountID = nil
                                    } else {
                                        editingAccountID = account.id
                                        editingICS = account.icsURL ?? ""
                                    }
                                }) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11))
                                        .foregroundColor(editingAccountID == account.id ? GlassTheme.accentCyan : .secondary)
                                }
                                .buttonStyle(.pressable)
                                .help("Configure iCal Secret Sync URL")
                            }
                            
                            Toggle("", isOn: Binding(
                                get: { account.isEnabled },
                                set: { _ in calendarService.toggleAccountEnabled(id: account.id) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            
                            Button(role: .destructive, action: {
                                calendarService.removeAccount(id: account.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.pressable)
                        }
                        
                        if editingAccountID == account.id {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Google Calendar Secret iCal URL:")
                                    .font(AppTypography.micro)
                                    .foregroundColor(.white.opacity(0.75))
                                
                                HStack {
                                    TextField("https://calendar.google.com/calendar/ical/.../basic.ics", text: $editingICS)
                                        .textFieldStyle(.roundedBorder)
                                        .font(AppTypography.caption)
                                    
                                    Button("Save") {
                                        calendarService.updateAccountICS(id: account.id, icsURL: editingICS)
                                        editingAccountID = nil
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                }
            }
            }
            .frame(maxHeight: 320)
        }
        .padding(16)
        .frame(width: sheetWidth)
    }
}

private extension CalendarAccountQuickSheet {
    func startRename(for account: CalendarAccount) {
        renameText = account.name
        renamingAccountID = account.id
        DispatchQueue.main.async { isRenameFieldFocused = true }
    }
    
    func saveRename(for account: CalendarAccount) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != account.name {
            var updated = account
            updated.name = trimmed
            calendarService.updateAccount(updated)
        }
        renamingAccountID = nil
    }
}

/// Lists the Google accounts signed in on this Mac so each can be linked with one click.
private struct MacGoogleAccountsSection: View {
    @ObservedObject var calendarService: CalendarService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Google accounts on this Mac")
                    .font(AppTypography.bodyBold)
                Spacer()
                Button(action: openInternetAccounts) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text("Add Google Account")
                    }
                    .font(AppTypography.micro)
                    .foregroundColor(GlassTheme.accentCyan)
                }
                .buttonStyle(.pressable)
                .help("Opens System Settings > Internet Accounts")
            }
            
            if !calendarService.hasCalendarAccess {
                HStack(spacing: 8) {
                    Text("Allow calendar access so Master Dock can see your accounts.")
                        .font(AppTypography.micro)
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Button("Allow Access", action: openCalendarPrivacy)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            } else if calendarService.detectedSources.isEmpty {
                Text("No Google accounts found. Click Add Google Account, sign in, and turn on Calendars. It will show up here.")
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(calendarService.detectedSources) { source in
                    HStack(spacing: 8) {
                        Image(systemName: CalendarAccountType.googleCalendar.iconName)
                            .font(.system(size: 13))
                            .foregroundColor(CalendarAccountType.googleCalendar.brandAccentColor)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(source.email)
                                .font(AppTypography.captionBold)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(source.calendarCount) calendar\(source.calendarCount == 1 ? "" : "s")")
                                .font(AppTypography.micro)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if source.isLinked {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Linked")
                            }
                            .font(AppTypography.micro)
                            .foregroundColor(GlassTheme.accentEmerald)
                        } else {
                            Button("Link") {
                                calendarService.linkDetectedSource(id: source.id)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            Text("Google accounts added to this Mac link automatically, and each keeps its own events.")
                .font(AppTypography.micro)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
        .onAppear {
            Task { await calendarService.refreshEvents() }
        }
    }
    
    private func openInternetAccounts() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.internetaccounts"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }
    
    private func openCalendarPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct AddCalendarEventQuickSheet: View {
    @ObservedObject var calendarService: CalendarService
    @Binding var isPresented: Bool
    
    @State private var selectedAccountID: String = ""
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var location: String = ""
    @State private var isAllDay: Bool = false
    @State private var quickText: String = ""
    @State private var quickPreview: NaturalLanguageEventParser.ParsedEvent?
    @State private var calendars: [CalendarService.WritableCalendar] = []
    @State private var selectedCalendarID: String = ""
    @State private var saveError: String?
    
    private var selectedCalendar: CalendarService.WritableCalendar? {
        calendars.first { $0.id == selectedCalendarID }
    }
    
    private func saveEvent() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        var joinURL: URL? = nil
        if let directURL = URL(string: location.trimmingCharacters(in: .whitespaces)), ICalendarParser.isMeetingURL(directURL) {
            joinURL = directURL
        } else if let extracted = ICalendarParser.extractMeetingURL(from: location) {
            joinURL = extracted
        }
        
        if let target = selectedCalendar {
            do {
                try calendarService.saveEvent(
                    toCalendar: target.id,
                    title: cleanTitle,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    location: location.isEmpty ? nil : location,
                    meetingURL: joinURL
                )
                isPresented = false
            } catch {
                saveError = error.localizedDescription
            }
            return
        }
        
        // No calendar access: keep it in Master Dock only.
        let targetID = selectedAccountID.isEmpty ? (activeAccounts.first?.id ?? "") : selectedAccountID
        calendarService.addCustomEvent(
            to: targetID,
            title: cleanTitle,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            joinURL: joinURL,
            isAllDay: isAllDay
        )
        isPresented = false
    }
    
    private var activeAccounts: [CalendarAccount] {
        calendarService.accounts.filter { $0.isLinked && $0.isEnabled }
    }
    
    /// Typing a sentence fills in the title, day and times below as you type.
    private func applyQuickText(_ text: String) {
        guard let parsed = NaturalLanguageEventParser.parse(text) else {
            quickPreview = nil
            return
        }
        quickPreview = parsed
        title = parsed.title
        startDate = parsed.start
        endDate = parsed.end
        isAllDay = parsed.isAllDay
    }
    
    private func quickPreviewText(_ p: NaturalLanguageEventParser.ParsedEvent) -> String {
        let day = DateFormatter()
        day.dateFormat = "EEE, MMM d"
        if p.isAllDay { return "\(p.title) • \(day.string(from: p.start)) • All day" }
        let time = DateFormatter()
        time.dateFormat = "h:mm a"
        return "\(p.title) • \(day.string(from: p.start)) • \(time.string(from: p.start)) to \(time.string(from: p.end))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 15))
                        .foregroundColor(GlassTheme.accentCyan)
                    Text("Add Event")
                        .font(AppTypography.titleMedium)
                }
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.pressable)
                .foregroundColor(.secondary)
            }
            
            // Natural-language quick add
            VStack(alignment: .leading, spacing: 6) {
                Text("Just type it")
                    .font(AppTypography.captionBold)
                TextField("e.g. Calc study Friday 4pm for 2 hours", text: $quickText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: quickText) { _, newValue in applyQuickText(newValue) }
                if let preview = quickPreview {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .foregroundColor(GlassTheme.accentCyan)
                        Text(quickPreviewText(preview))
                            .lineLimit(1)
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.85))
                } else if !quickText.isEmpty {
                    Text("Add a day or time, like \"tomorrow 3pm\" or \"Friday\".")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !calendars.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Save to")
                        .font(AppTypography.captionBold)
                    Picker("Calendar", selection: $selectedCalendarID) {
                        ForEach(calendars) { cal in
                            Text(cal.displayName).tag(cal.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text(selectedCalendar?.isGoogle == true
                         ? "Saves to your Google Calendar too, so it shows on your phone."
                         : "Saves to your real calendar on this Mac.")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
            } else if !activeAccounts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Calendar Account")
                        .font(AppTypography.captionBold)
                    Text("Without Calendar access this event is only saved in Master Dock.")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                    Picker("Account", selection: $selectedAccountID) {
                        ForEach(activeAccounts) { acc in
                            HStack {
                                Image(systemName: acc.accountType.iconName)
                                Text(acc.name)
                            }
                            .tag(acc.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Event Title")
                    .font(AppTypography.captionBold)
                TextField("e.g. Design Review, Client Sync", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(AppTypography.captionBold)
                    DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(AppTypography.captionBold)
                    DatePicker("", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            
            Toggle("All-day event", isOn: $isAllDay)
                .font(AppTypography.caption)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Location or meeting link (optional)")
                    .font(AppTypography.captionBold)
                TextField("e.g. Library, or paste a Zoom or Meet link", text: $location)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Spacer()
                Button("Add Event") { saveEvent() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            
            if let saveError {
                Text(saveError)
                    .font(AppTypography.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 360)
        .onAppear {
            if let first = activeAccounts.first {
                selectedAccountID = first.id
            }
            calendars = calendarService.writableCalendars()
            selectedCalendarID = (calendars.first(where: { $0.isGoogle }) ?? calendars.first(where: { $0.isDefault }) ?? calendars.first)?.id ?? ""
        }
    }
}

private struct MeetingCard: View {
    let meeting: CalendarMeeting
    @State private var isHovered = false
    
    private var sourceColor: Color {
        if meeting.countdownStatus == "Happening Now" {
            return GlassTheme.accentRose
        }
        return meeting.accountType?.brandAccentColor ?? GlassTheme.accentBlue
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Left Time & Brand Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(sourceColor)
                .frame(width: 3, height: 38)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let accountType = meeting.accountType {
                        HStack(spacing: 3) {
                            Image(systemName: accountType.iconName)
                                .font(.system(size: 9, weight: .bold))
                            if let accountName = meeting.accountName, !accountName.isEmpty {
                                Text(accountName)
                                    .font(AppTypography.micro)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundColor(accountType.brandAccentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(accountType.brandAccentColor.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(accountType.brandAccentColor.opacity(0.35), lineWidth: 0.5))
                    }
                    
                    Text(meeting.title)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let calendarName = meeting.calendarName, !calendarName.isEmpty, calendarName != meeting.accountName {
                        Text(calendarName)
                            .font(AppTypography.micro)
                            .foregroundColor(.white.opacity(0.55))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
                
                HStack(spacing: 6) {
                    Text(meeting.timeRangeString)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.75))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.45))
                        .font(AppTypography.caption)
                    
                    Text(meeting.countdownStatus)
                        .font(AppTypography.captionBold)
                        .foregroundColor(meeting.countdownStatus == "Happening Now" ? GlassTheme.accentRose : GlassTheme.accentEmerald)
                    
                    if let location = meeting.location, !location.isEmpty {
                        Text("•")
                            .foregroundColor(.white.opacity(0.45))
                            .font(AppTypography.caption)
                        
                        Text(location)
                            .font(AppTypography.micro)
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Only show Join when the event has an actual meeting link.
            if let joinURL = meeting.joinURL, ICalendarParser.isMeetingURL(joinURL) {
                Button(action: { NSWorkspace.shared.open(joinURL) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10))
                        Text("Join")
                            .font(AppTypography.captionBold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(sourceColor))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidPillStyle(cornerRadius: 12, isHovered: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}
