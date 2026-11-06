import SwiftUI
import MasterDockCore
import MasterDockServices
import MasterDockAI

public struct MasterDockRootView: View {
    // Each card watches its own service. The root only hands them down, so a song's progress
    // ticking or CPU stats updating no longer redraws the entire dock (that caused hitches).
    public let clipboardService: ClipboardMonitorService
    public let mediaService: MediaService
    public let calendarService: CalendarService
    public let wallpaperService: WallpaperService
    public let appLauncher: AppLauncherService
    public let folderService: FolderService
    public let statsService: SystemStatsService
    public let weatherService: WeatherService
    public let checklistService: ChecklistService
    public let promptService: PromptLibraryService
    public let audioPipeline: AudioRecordingPipeline
    
    @Binding public var isVoiceModeActive: Bool
    @Binding public var liveVoiceTranscript: String
    @Binding public var aiPromptInput: String
    @Binding public var conversationHistory: [AIMessage]
    @Binding public var isAIStreaming: Bool
    @Binding public var isPinned: Bool
    
    public var onSendMessage: (String) -> Void
    public var onClearChat: () -> Void
    public var onVoiceDone: () -> Void
    public var onStartVoice: () -> Void
    public var onOpenSettings: () -> Void
    public var onDismiss: () -> Void
    
    @State private var selectedTab: DockTab = .all
    @ObservedObject private var layout = DockLayoutStore.shared
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
        isPinned: Binding<Bool> = .constant(false),
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
        self._isPinned = isPinned
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
    
    /// The contents of each widget card.
    @ViewBuilder
    private func cardContent(for kind: DockWidgetKind) -> some View {
        switch kind {
        case .ai:
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
        case .media:
            MediaSectionView(mediaService: mediaService)
        case .calendar:
            CalendarSectionView(calendarService: calendarService)
        case .clipboard:
            ClipboardSectionView(clipboardService: clipboardService)
        case .checklist:
            ChecklistSectionView(checklistService: checklistService)
        case .notes:
            QuickNotesWidget()
        case .timer:
            FocusTimerWidget()
        case .calculator:
            CalculatorWidget()
        case .worldClock:
            WorldClockWidget()
        case .apps:
            AppFolderSectionView(appLauncher: appLauncher, folderService: folderService)
        case .wallpapers:
            WallpaperSectionView(wallpaperService: wallpaperService)
        case .system:
            WidgetDrawerSectionView(statsService: statsService, weatherService: weatherService)
        }
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
                .liquidGlassControl(Capsule(), interactive: false)
                
                Spacer()
                
                HStack(spacing: 7) {
                    GlassIconButton(
                        iconSystemName: isPinned ? "pin.fill" : "pin",
                        size: 28,
                        iconSize: 11,
                        accentColor: isPinned ? GlassTheme.accentCyan : nil,
                        helpText: isPinned ? "Dock is Pinned (Won't close on outside clicks)" : "Pin Dock (Keep open when clicking other apps)",
                        action: { isPinned.toggle() }
                    )
                    
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
                                // Real Liquid Glass chips; the selected tab is blue-tinted glass.
                                .liquidGlassControl(Capsule(), tint: selectedTab == tab ? GlassTheme.accentBlue.opacity(0.85) : nil)
                        }
                        .buttonStyle(.pressable)
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
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(Double(1.0 - tabLeadingFade)), location: 0.0),
                        .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.85),
                        .init(color: .black.opacity(Double(1.0 - tabTrailingFade)), location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.bottom, 4)
            
            // Main Scrollable Floating Cards with Dynamic Edge Fading
            ScrollView(.vertical, showsIndicators: false) {
                GlassGroup(spacing: 4) {
                VStack(spacing: 12) {
                    // Cards come from the user's layout (order, visibility and names are customizable).
                    ForEach(layout.visibleWidgets.filter { selectedTab == .all || $0.kind.tab == selectedTab }) { config in
                        EditableDockCard(kind: config.kind, layout: layout) {
                            GlassCard { cardContent(for: config.kind) }
                        }
                        .environment(\.dockCardKind, config.kind)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                    
                    if layout.isEditing {
                        GlassCard { HiddenWidgetsPanel(layout: layout) }
                            .transition(.opacity)
                    }
                }
                }
                .padding(.horizontal, 16)
                // Extra room above the first card so its soft shadow isn't cropped at the top of
                // the scroll area (a cropped shadow showed up as a hard horizontal line).
                .padding(.top, 4 + GlassTheme.cardShadowBleed)
                .padding(.bottom, 20)
                // Extra room to the right so the cards' soft shadow isn't cropped by the scroll
                // area (a cropped shadow showed up as a gray band with a hard edge).
                .padding(.trailing, GlassTheme.cardShadowBleed)
                .background(
                    // Short, soft fade like Notification Center
                    // When scrolled, cards dissolve over the extended top area so they're gone
                    // before reaching the header buttons. Unscrolled, nothing is masked.
                    ScrollEdgeFadeObserver(fadeLength: 14.0, fadeThreshold: 12.0, startFadeLength: GlassTheme.cardShadowBleed + 14.0)
                )
            }
            // Let the scroll area reach into the see-through strip beside the dock, and up behind
            // the header so the top card's shadow can fade out naturally.
            .padding(.trailing, -GlassTheme.cardShadowBleed)
            .padding(.top, -GlassTheme.cardShadowBleed)
            // Keep the header buttons above the scroll area so they stay visible and clickable.
            .zIndex(-1)
            
            // Bottom Floating Liquid Glass Bar (Matching macOS Notification Center bottom bar)
            HStack(spacing: 8) {
                GlassPillButton(
                    title: layout.isEditing ? "Done" : "Edit Widgets",
                    iconSystemName: layout.isEditing ? "checkmark" : "slider.horizontal.3"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1)) {
                        layout.isEditing.toggle()
                        if layout.isEditing { selectedTab = .all }
                    }
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
