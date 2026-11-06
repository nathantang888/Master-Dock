import SwiftUI
import MasterDockCore
import MasterDockServices
import MasterDockAI

public struct SettingsWindowView: View {
    @ObservedObject public var permissionManager = PermissionManager.shared
    
    @AppStorage("dock_width") private var dockWidth: Double = 340.0
    @AppStorage("ai_provider") private var selectedProvider: String = AIProvider.appleIntelligence.rawValue
    @AppStorage("openai_key") private var openAIKey: String = ""
    @AppStorage("gemini_key") private var geminiKey: String = ""
    @AppStorage("ollama_host") private var ollamaHost: String = "http://localhost:11434"
    @AppStorage("launch_at_login") private var launchAtLogin: Bool = true
    
    @AppStorage("masterdock_preferred_media_source") private var preferredSource: String = MediaSource.spotify.rawValue
    @ObservedObject public var mediaService = MediaService.shared
    @ObservedObject public var calendarService = CalendarService.shared
    
    @State private var isAddAccountSheetPresented = false
    @State private var newAccountType: CalendarAccountType = .googleCalendar
    @State private var newAccountName: String = ""
    @State private var newAccountEmail: String = ""
    @State private var newAccountICSURL: String = ""
    
    public init() {}
    
    public var body: some View {
        TabView {
            // 1. Appearance & Dock Width Tab
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "slider.horizontal.3")
                }
            
            // Widgets: order, visibility and names
            WidgetsSettingsView()
                .tabItem {
                    Label("Widgets", systemImage: "square.grid.2x2")
                }
            
            // 2. Media & Music Tab
            mediaSettingsTab
                .tabItem {
                    Label("Media & Music", systemImage: "music.note")
                }
            
            // 3. Calendars & Accounts Tab
            calendarSettingsTab
                .tabItem {
                    Label("Calendars", systemImage: "calendar.badge.plus")
                }
            
            // 4. General & Permissions Tab
            generalSettingsTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            // 4. Gestures & Shortcuts Tab
            gesturesTab
                .tabItem {
                    Label("Gestures", systemImage: "hand.tap.fill")
                }
            
            // 5. Apple Intelligence & AI Models Tab
            aiSettingsTab
                .tabItem {
                    Label("Intelligence", systemImage: "apple.intelligence")
                }
            
            // 6. Blur Lab: live tuning of the background blur
            BlurLabSettingsView()
                .tabItem {
                    Label("Blur Lab", systemImage: "drop.halffull")
                }
        }
        .frame(width: 560, height: 490)
        .padding()
    }
    
    // MARK: - Appearance Tab
    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Dock Dimensions & Sizing")
                .font(AppTypography.titleMedium)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Dock Width:")
                        .font(AppTypography.bodyBold)
                    
                    Spacer()
                    
                    Text("\(Int(dockWidth)) pt")
                        .font(AppTypography.captionBold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(GlassTheme.accentBlue.opacity(0.18)))
                        .foregroundColor(GlassTheme.accentCyan)
                }
                
                Slider(value: $dockWidth, in: 240...480, step: 2.5)
                    .accentColor(GlassTheme.accentCyan)
                
                HStack(spacing: 8) {
                    Button("Compact (260pt)") {
                        withAnimation { dockWidth = 260 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Default (292pt)") {
                        withAnimation { dockWidth = 292.5 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Comfortable (350pt)") {
                        withAnimation { dockWidth = 350 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Wide (390pt)") {
                        withAnimation { dockWidth = 390 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Text("Changes take effect immediately on the live dock.")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Visual Style")
                    .font(AppTypography.bodyBold)
                
                Text("Master Dock utilizes Apple's native glassmorphic background blur and specular liquid materials.")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - General Tab
    private var generalSettingsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Permissions & System Access")
                .font(AppTypography.titleMedium)
            
            VStack(spacing: 10) {
                PermissionRow(
                    title: "Accessibility (Simulate Paste & Gestures)",
                    isGranted: permissionManager.isAccessibilityGranted
                ) {
                    permissionManager.requestAccessibility()
                } onOpenSettings: {
                    permissionManager.openSystemSettings(for: .accessibility)
                }
                
                PermissionRow(
                    title: "Microphone (AI Voice Mode)",
                    isGranted: permissionManager.isMicrophoneGranted
                ) {
                    permissionManager.requestMicrophone()
                } onOpenSettings: {
                    permissionManager.openSystemSettings(for: .microphone)
                }
                
                PermissionRow(
                    title: "Calendar Access (Today's Events)",
                    isGranted: permissionManager.isCalendarGranted
                ) {
                    permissionManager.requestCalendar()
                } onOpenSettings: {
                    permissionManager.openSystemSettings(for: .calendar)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            Toggle("Launch Master Dock at login", isOn: $launchAtLogin)
                .font(AppTypography.body)
            
            Spacer()
        }
        .padding()
        .onAppear {
            permissionManager.checkAllPermissions()
        }
    }
    
    // MARK: - Gestures Tab
    private var gesturesTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trackpad Gestures")
                .font(AppTypography.titleMedium)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 24))
                        .foregroundColor(GlassTheme.accentCyan)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2-Finger Left Edge Swipe")
                            .font(AppTypography.bodyBold)
                        Text("Swiping from the left edge (0 to 1/3 width) opens Master Dock. Swiping past 1/2 activates Voice Mode.")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 24))
                        .foregroundColor(GlassTheme.accentRose)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2-Finger Top Edge Swipe")
                            .font(AppTypography.bodyBold)
                        Text("Swiping from top to bottom directly launches the Apple Intelligence Voice Assistant.")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 24))
                        .foregroundColor(GlassTheme.accentBlue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Keyboard Shortcuts")
                            .font(AppTypography.bodyBold)
                        Text("Option + Space: Toggle Dock  |  Option + Shift + Space: Toggle Voice Mode")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Intelligence Tab
    private var aiSettingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                AppleIntelligenceGlyph(size: 20)
                Text("Apple Intelligence & Models")
                    .font(AppTypography.titleMedium)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Picker("AI Engine", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.rawValue).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.menu)
                
                if selectedProvider == AIProvider.appleIntelligence.rawValue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(" Running Apple Foundation Model natively on Apple Silicon.")
                            .font(AppTypography.bodyBold)
                            .foregroundColor(GlassTheme.accentCyan)
                        Text("100% private on-device neural execution with zero cloud latency.")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                } else if selectedProvider == AIProvider.openAI.rawValue {
                    SecureField("OpenAI API Key (sk-...)", text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                } else if selectedProvider == AIProvider.gemini.rawValue {
                    SecureField("Google Gemini API Key", text: $geminiKey)
                        .textFieldStyle(.roundedBorder)
                } else if selectedProvider == AIProvider.ollama.rawValue {
                    TextField("Local Ollama Host", text: $ollamaHost)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Media & Music Tab
    private var mediaSettingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Music Services & Controller Setup")
                .font(AppTypography.titleMedium)
            
            VStack(alignment: .leading, spacing: 12) {
                Picker("Default Music Platform", selection: $preferredSource) {
                    Text("Spotify").tag(MediaSource.spotify.rawValue)
                    Text("Apple Music").tag(MediaSource.appleMusic.rawValue)
                    Text("YouTube Music").tag(MediaSource.youtubeMusic.rawValue)
                    Text("System Audio / Generic").tag(MediaSource.system.rawValue)
                }
                .pickerStyle(.menu)
                .onChange(of: preferredSource) { _, newValue in
                    if let source = MediaSource(rawValue: newValue) {
                        mediaService.selectSource(source)
                    }
                }
                
                Text("Master Dock will automatically connect to this platform when launching playback or quick mixes.")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Connected Music Services")
                    .font(AppTypography.bodyBold)
                
                ForEach(mediaService.platforms) { platform in
                    HStack(spacing: 10) {
                        Image(systemName: platform.source.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(platform.source.brandAccentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(platform.source.rawValue)
                                .font(AppTypography.bodyBold)
                            Text(platform.isAppRunning ? "App Running & Scriptable" : (platform.isAppInstalled ? "App Installed" : "Web / Browser Integration"))
                                .font(AppTypography.micro)
                                .foregroundColor(platform.isAppRunning ? GlassTheme.accentEmerald : .secondary)
                        }
                        
                        Spacer()
                        
                        if platform.source == .youtubeMusic {
                            Button("Open Web Player") {
                                mediaService.openYouTubeMusic()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else if platform.isAppInstalled {
                            Button(platform.isAppRunning ? "Connected" : "Launch") {
                                mediaService.selectSource(platform.source)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Calendars Tab
    private var calendarSettingsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar Accounts & Integration")
                        .font(AppTypography.titleMedium)
                    Text("Link multiple Google Calendar and Apple Calendar accounts to merge your schedule.")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    newAccountName = ""
                    newAccountEmail = ""
                    newAccountICSURL = ""
                    newAccountType = .googleCalendar
                    isAddAccountSheetPresented = true
                }) {
                    Label("Link Account", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Connected Accounts")
                        .font(AppTypography.bodyBold)
                    Spacer()
                    Button(action: {
                        if let url = URL(string: "https://calendar.google.com/calendar/u/0/r/settings") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Google Calendar Web")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                    if calendarService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        Button("Sync All") {
                            Task {
                                await calendarService.refreshEvents()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
                
                if calendarService.accounts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No calendar accounts linked yet.")
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(calendarService.accounts) { account in
                                calendarAccountRow(account)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
            
            // System Permission Info Box
            HStack(spacing: 12) {
                Image(systemName: permissionManager.isCalendarGranted ? "checkmark.seal.fill" : "info.circle")
                    .font(.system(size: 18))
                    .foregroundColor(permissionManager.isCalendarGranted ? GlassTheme.accentEmerald : GlassTheme.accentAmber)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(permissionManager.isCalendarGranted ? "Apple Calendar Access Enabled" : "Apple Calendar Access Needed")
                        .font(AppTypography.captionBold)
                    Text(permissionManager.isCalendarGranted ? "Master Dock has permission to read system Apple Calendars." : "Grant access in System Settings to read macOS Apple Calendar events.")
                        .font(AppTypography.micro)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !permissionManager.isCalendarGranted {
                    Button("Grant") {
                        permissionManager.requestCalendar()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $isAddAccountSheetPresented) {
            linkAccountSheet
        }
    }
    
    private func calendarAccountRow(_ account: CalendarAccount) -> some View {
        HStack(spacing: 10) {
            Image(systemName: account.accountType.iconName)
                .font(.system(size: 16))
                .foregroundColor(account.accountType.brandAccentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(AppTypography.bodyBold)
                    if account.icsURL != nil {
                        Text("iCal Live")
                            .font(AppTypography.micro)
                            .foregroundColor(GlassTheme.accentEmerald)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(GlassTheme.accentEmerald.opacity(0.15)))
                    }
                    if !account.isEnabled {
                        Text("(Disabled)")
                            .font(AppTypography.micro)
                            .foregroundColor(.secondary)
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
            
            Toggle("", isOn: Binding(
                get: { account.isEnabled },
                set: { _ in calendarService.toggleAccountEnabled(id: account.id) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(account.isEnabled ? "Disable Calendar Sync" : "Enable Calendar Sync")
            
            Menu {
                if account.accountType == .googleCalendar {
                    Button("Open Google Calendar Web") {
                        if let url = URL(string: "https://calendar.google.com/calendar/u/0/r/settings") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Divider()
                }
                if account.isLinked {
                    Button("Unlink Account") {
                        calendarService.unlinkAccount(id: account.id)
                    }
                } else {
                    Button("Re-link Account") {
                        var updated = account
                        updated.isLinked = true
                        updated.isEnabled = true
                        calendarService.linkAccount(updated)
                    }
                }
                Divider()
                Button(role: .destructive) {
                    calendarService.removeAccount(id: account.id)
                } label: {
                    Text("Delete Account")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(account.isEnabled ? 0.04 : 0.015)))
    }
    
    private var linkAccountSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Link Calendar Account")
                    .font(AppTypography.titleMedium)
                Spacer()
                Button("Cancel") {
                    isAddAccountSheetPresented = false
                }
                .buttonStyle(.pressable)
                .foregroundColor(.secondary)
            }
            
            Picker("Account Service", selection: $newAccountType) {
                ForEach(CalendarAccountType.allCases) { type in
                    HStack {
                        Image(systemName: type.iconName)
                        Text(type.rawValue)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Account Display Name")
                    .font(AppTypography.captionBold)
                TextField(newAccountType == .googleCalendar ? "e.g. Work Google Calendar" : "e.g. Personal Apple Calendar", text: $newAccountName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Email / Identifier")
                    .font(AppTypography.captionBold)
                TextField(newAccountType == .googleCalendar ? "name@gmail.com" : "name@icloud.com", text: $newAccountEmail)
                    .textFieldStyle(.roundedBorder)
            }
            
            if newAccountType == .googleCalendar {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Google Calendar iCal / Secret ICS URL")
                            .font(AppTypography.captionBold)
                        Text("(Optional for Live Sync)")
                            .font(AppTypography.micro)
                            .foregroundColor(.secondary)
                    }
                    TextField("https://calendar.google.com/calendar/ical/.../basic.ics", text: $newAccountICSURL)
                        .textFieldStyle(.roundedBorder)
                    Text("To get this in Google Calendar: Settings > Integrate calendar > Secret address in iCal format.")
                        .font(AppTypography.micro)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    isAddAccountSheetPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Link Account") {
                    let title = newAccountName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "\(newAccountType.rawValue) (\(newAccountEmail.isEmpty ? "Account" : newAccountEmail))"
                        : newAccountName.trimmingCharacters(in: .whitespaces)
                    
                    let newAccount = CalendarAccount(
                        name: title,
                        accountType: newAccountType,
                        emailOrUsername: newAccountEmail.trimmingCharacters(in: .whitespaces),
                        isLinked: true,
                        isEnabled: true,
                        icsURL: newAccountICSURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newAccountICSURL.trimmingCharacters(in: .whitespaces)
                    )
                    calendarService.linkAccount(newAccount)
                    isAddAccountSheetPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 440)
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isGranted ? GlassTheme.accentEmerald : GlassTheme.accentAmber)
            
            Text(title)
                .font(AppTypography.body)
            
            Spacer()
            
            if !isGranted {
                Button("Grant Access", action: onRequest)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                
                Button("Open Settings", action: onOpenSettings)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Text("Granted")
                    .font(AppTypography.captionBold)
                    .foregroundColor(GlassTheme.accentEmerald)
            }
        }
    }
}


/// Live controls for the blur behind the dock. Every change applies to the dock instantly.
private struct BlurLabSettingsView: View {
    @AppStorage(DockBlurSettings.methodKey) private var method: String = DockBlurSettings.defaultMethod.rawValue
    @AppStorage(DockBlurSettings.radiusKey) private var radius: Double = DockBlurSettings.defaultRadius
    @AppStorage(DockBlurSettings.fadeKey) private var fade: Double = DockBlurSettings.defaultFade
    @AppStorage(DockBlurSettings.hazeKey) private var haze: Double = DockBlurSettings.defaultHaze
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Blur Lab")
                .font(AppTypography.titleMedium)
            Text("Changes apply to the dock right away. Keep the dock open next to Notification Center to compare.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
            
            Picker("Method", selection: $method) {
                Text("Bands").tag(DockBlurMethod.bands.rawValue)
                Text("Fade").tag(DockBlurMethod.fade.rawValue)
                Text("Variable").tag(DockBlurMethod.variable.rawValue)
            }
            .pickerStyle(.segmented)
            
            labeledSlider("Blur strength", value: $radius, range: 0...30, step: 1, format: "%.0f")
            labeledSlider("Fade distance", value: $fade, range: 4...120, step: 4, format: "%.0f pt")
            labeledSlider("White haze", value: $haze, range: 0...0.6, step: 0.02, format: "%.2f")
            
            HStack {
                Spacer()
                Button("Reset") {
                    method = DockBlurSettings.defaultMethod.rawValue
                    radius = DockBlurSettings.defaultRadius
                    fade = DockBlurSettings.defaultFade
                    haze = DockBlurSettings.defaultHaze
                }
            }
            Spacer()
        }
        .padding(20)
    }
    
    private func labeledSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title).font(AppTypography.bodyBold)
                Spacer()
                Button("−") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                .help("Decrease \(title.lowercased())")
                Text(String(format: format, value.wrappedValue))
                    .font(AppTypography.monoNumber)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 56, alignment: .trailing)
                Button("+") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
                .help("Increase \(title.lowercased())")
            }
            Slider(value: value, in: range, step: step)
        }
    }
}


/// Settings > Widgets: drag to reorder, switch widgets on or off, and rename them.
private struct WidgetsSettingsView: View {
    @ObservedObject private var layout = DockLayoutStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Widgets")
                    .font(AppTypography.titleMedium)
                Spacer()
                Button("Reset to Default") { layout.resetToDefault() }
            }
            Text("Drag to reorder. Switch a widget off to hide it. Type a new name to rename it on the dock.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
            
            List {
                ForEach(layout.widgets) { config in
                    WidgetSettingsRow(config: config, layout: layout)
                }
                .onMove { source, destination in
                    layout.move(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding(20)
    }
}

private struct WidgetSettingsRow: View {
    let config: DockWidgetConfig
    @ObservedObject var layout: DockLayoutStore
    @State private var name: String = ""
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
            Image(systemName: config.kind.iconName)
                .frame(width: 18)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                TextField(config.kind.defaultTitle, text: $name)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyBold)
                    .onSubmit { layout.rename(config.kind, to: name) }
                    .onChange(of: name) { _, newValue in layout.rename(config.kind, to: newValue) }
                Text(config.kind.summary)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if config.customTitle != nil {
                Button("Reset Name") {
                    layout.resetTitle(config.kind)
                    name = config.kind.defaultTitle
                }
                .controlSize(.small)
            }
            Toggle("", isOn: Binding(
                get: { config.isVisible },
                set: { layout.setVisible(config.kind, $0, reposition: false) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 3)
        .onAppear { name = config.customTitle ?? config.kind.defaultTitle }
    }
}
