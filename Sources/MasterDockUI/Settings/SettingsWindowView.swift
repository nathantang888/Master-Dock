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
    
    public init() {}
    
    public var body: some View {
        TabView {
            // 1. Appearance & Dock Width Tab
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "slider.horizontal.3")
                }
            
            // 2. Media & Music Tab
            mediaSettingsTab
                .tabItem {
                    Label("Media & Music", systemImage: "music.note")
                }
            
            // 3. General & Permissions Tab
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
