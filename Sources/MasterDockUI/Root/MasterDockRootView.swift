import SwiftUI
import MasterDockCore
import MasterDockServices
import MasterDockAI

public struct MasterDockRootView: View {
    @ObservedObject public var clipboardService: ClipboardMonitorService
    @ObservedObject public var mediaService: MediaService
    @ObservedObject public var calendarService: CalendarService
    @ObservedObject public var wallpaperService: WallpaperService
    @ObservedObject public var appLauncher: AppLauncherService
    @ObservedObject public var folderService: FolderService
    @ObservedObject public var statsService: SystemStatsService
    @ObservedObject public var weatherService: WeatherService
    @ObservedObject public var checklistService: ChecklistService
    @ObservedObject public var promptService: PromptLibraryService
    @ObservedObject public var audioPipeline: AudioRecordingPipeline
    
    @Binding public var isVoiceModeActive: Bool
    @Binding public var liveVoiceTranscript: String
    @Binding public var aiPromptInput: String
    @Binding public var conversationHistory: [AIMessage]
    @Binding public var isAIStreaming: Bool
    
    public var onSendMessage: (String) -> Void
    public var onClearChat: () -> Void
    public var onVoiceDone: () -> Void
    public var onStartVoice: () -> Void
    public var onOpenSettings: () -> Void
    public var onDismiss: () -> Void
    
    @State private var selectedTab: DockTab = .all
    @State private var tabLeadingFade: CGFloat = 0.0
    @State private var tabTrailingFade: CGFloat = 1.0
    
    public enum DockTab: String, CaseIterable, Identifiable {
        case all = "All"
        case ai = "AI"
        case clipboard = "Clipboard"
        case agenda = "Agenda"
        case apps = "Apps"
        case widgets = "Widgets"
        
        public var id: String { rawValue }
    }
    
    public init(
        clipboardService: ClipboardMonitorService = .shared,
        mediaService: MediaService = .shared,
        calendarService: CalendarService = .shared,
        wallpaperService: WallpaperService = .shared,
        appLauncher: AppLauncherService = .shared,
        folderService: FolderService = .shared,
        statsService: SystemStatsService = .shared,
        weatherService: WeatherService = .shared,
        checklistService: ChecklistService = .shared,
        promptService: PromptLibraryService = .shared,
        audioPipeline: AudioRecordingPipeline = .shared,
        isVoiceModeActive: Binding<Bool>,
        liveVoiceTranscript: Binding<String> = .constant(""),
        aiPromptInput: Binding<String>,
        conversationHistory: Binding<[AIMessage]>,
        isAIStreaming: Binding<Bool>,
        onSendMessage: @escaping (String) -> Void,
        onClearChat: @escaping () -> Void,
        onVoiceDone: @escaping () -> Void,
        onStartVoice: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.clipboardService = clipboardService
        self.mediaService = mediaService
        self.calendarService = calendarService
        self.wallpaperService = wallpaperService
        self.appLauncher = appLauncher
        self.folderService = folderService
        self.statsService = statsService
        self.weatherService = weatherService
        self.checklistService = checklistService
        self.promptService = promptService
        self.audioPipeline = audioPipeline
        self._isVoiceModeActive = isVoiceModeActive
        self._liveVoiceTranscript = liveVoiceTranscript
        self._aiPromptInput = aiPromptInput
        self._conversationHistory = conversationHistory
        self._isAIStreaming = isAIStreaming
        self.onSendMessage = onSendMessage
        self.onClearChat = onClearChat
        self.onVoiceDone = onVoiceDone
        self.onStartVoice = onStartVoice
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            if isVoiceModeActive {
                GlassCard {
                    AIVoiceOverlayView(
                        audioPipeline: audioPipeline,
                        liveTranscript: liveVoiceTranscript,
                        userPrompt: conversationHistory.filter { $0.role == .user }.last?.content ?? "",
                        aiResponseText: conversationHistory.filter { $0.role == .assistant }.last?.content ?? "",
                        isAIStreaming: isAIStreaming,
                        onClose: { isVoiceModeActive = false },
                        onStopAndSend: onVoiceDone,
                        onStartRecording: onStartVoice
                    )
                }
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                standardDockContent
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVoiceModeActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .liquidPanelBackground()
        .preferredColorScheme(.dark)
    }
    
    private var standardDockContent: some View {
        VStack(spacing: 8) {
            // Clean Top Header Bar (Matching macOS Notification Center Header)
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "dock.rectangle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(GlassTheme.accentCyan)
                        .shadow(color: GlassTheme.accentCyan.opacity(0.6), radius: 4, x: 0, y: 0)
                    
                    Text("Master Dock")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        Capsule()
                            .fill(.regularMaterial)
                        Capsule()
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.80))
                        Capsule()
                            .fill(GlassTheme.liquidGlassSheen)
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(GlassTheme.subtleSpecularBorder, lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 1)
                
                Spacer()
                
                HStack(spacing: 7) {
                    GlassIconButton(
                        iconSystemName: "mic.fill",
                        size: 28,
                        iconSize: 11,
                        helpText: "Apple Intelligence Voice Companion",
                        action: { isVoiceModeActive = true; onStartVoice() }
                    )
                    
                    GlassIconButton(
                        iconSystemName: "gearshape.fill",
                        size: 28,
                        iconSize: 11,
                        helpText: "Master Dock Preferences",
                        action: onOpenSettings
                    )
                    
                    GlassIconButton(
                        iconSystemName: "xmark",
                        size: 28,
                        iconSize: 10,
                        helpText: "Dismiss Dock",
                        action: onDismiss
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 2)
            
            // Floating Tab Filter Bar (Smooth Single-Line Scrollable with Dynamic Edge Fading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DockTab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab.rawValue)
                                .font(AppTypography.captionBold)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.85))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(
                                    ZStack {
                                        Capsule()
                                            .fill(.regularMaterial)
                                        Capsule()
                                            .fill(selectedTab == tab ? AnyShapeStyle(GlassTheme.accentBlue.opacity(0.85)) : AnyShapeStyle(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.75)))
                                        Capsule()
                                            .fill(selectedTab == tab ? GlassTheme.liquidGlassHoverSheen : GlassTheme.liquidGlassSheen)
                                    }
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(selectedTab == tab ? AnyShapeStyle(Color.white.opacity(0.60)) : AnyShapeStyle(GlassTheme.subtleSpecularBorder), lineWidth: 0.75)
                                )
                                .shadow(color: selectedTab == tab ? GlassTheme.accentBlue.opacity(0.40) : Color.black.opacity(0.25), radius: selectedTab == tab ? 6 : 3, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    ScrollEdgeFadeObserver(
                        axis: .horizontal,
                        fadeLength: 32.0,
                        fadeThreshold: 10.0,
                        onFadeChange: { leading, trailing in
                            if abs(tabLeadingFade - leading) > 0.01 || abs(tabTrailingFade - trailing) > 0.01 {
                                withAnimation(.easeInOut(duration: 0.10)) {
                                    tabLeadingFade = leading
                                    tabTrailingFade = trailing
                                }
                            }
                        }
                    )
                )
            }
            .padding(.bottom, 4)
            
            // Main Scrollable Floating Cards with Dynamic Edge Fading
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // 1. Apple Intelligence & Prompts
                    if selectedTab == .all || selectedTab == .ai {
                        GlassCard {
                            VStack(spacing: 12) {
                                AIChatSectionView(
                                    promptText: $aiPromptInput,
                                    conversation: $conversationHistory,
                                    isStreaming: $isAIStreaming,
                                    onSendMessage: onSendMessage,
                                    onClear: onClearChat
                                )
                                
                                AIPromptsSectionView(promptService: promptService) { action in
                                    let clipboardText = clipboardService.items.first(where: { $0.type == .text })?.textContent ?? ""
                                    let resolved = promptService.resolvePrompt(action, clipboardContent: clipboardText)
                                    onSendMessage(resolved)
                                }
                            }
                        }
                    }
                    
                    // 2. Clipboard History
                    if selectedTab == .all || selectedTab == .clipboard {
                        GlassCard {
                            ClipboardSectionView(clipboardService: clipboardService)
                        }
                    }
                    
                    // 3. Today's Calendar & Schedule
                    if selectedTab == .all || selectedTab == .agenda {
                        GlassCard {
                            CalendarSectionView(calendarService: calendarService)
                        }
                    }
                    
                    // 4. Media Controller
                    if selectedTab == .all || selectedTab == .agenda {
                        GlassCard {
                            MediaSectionView(mediaService: mediaService)
                        }
                    }
                    
                    // 5. Daily Checklist
                    if selectedTab == .all || selectedTab == .agenda {
                        GlassCard {
                            ChecklistSectionView(checklistService: checklistService)
                        }
                    }
                    
                    // 6. Favorite Apps & Quick Folders
                    if selectedTab == .all || selectedTab == .apps {
                        GlassCard {
                            AppFolderSectionView(appLauncher: appLauncher, folderService: folderService)
                        }
                    }
                    
                    // 7. Wallpapers
                    if selectedTab == .all || selectedTab == .widgets {
                        GlassCard {
                            WallpaperSectionView(wallpaperService: wallpaperService)
                        }
                    }
                    
                    // 8. Widget Drawer & System Stats
                    if selectedTab == .all || selectedTab == .widgets {
                        GlassCard {
                            WidgetDrawerSectionView(statsService: statsService, weatherService: weatherService)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 20)
                .background(
                    ScrollEdgeFadeObserver(fadeLength: 38.0, fadeThreshold: 16.0)
                )
            }
            
            // Bottom Floating Liquid Glass Bar (Matching macOS Notification Center bottom bar)
            HStack(spacing: 8) {
                GlassPillButton(title: "Edit Widgets", iconSystemName: "slider.horizontal.3") {
                    onOpenSettings()
                }
                
                GlassIconButton(
                    iconSystemName: "xmark",
                    size: 30,
                    iconSize: 10,
                    helpText: "Close Master Dock",
                    action: onDismiss
                )
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
