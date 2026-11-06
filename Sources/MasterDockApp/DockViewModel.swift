import Foundation
import SwiftUI
import Combine
import MasterDockCore
import MasterDockServices
import MasterDockAI
import MasterDockUI

@MainActor
public final class DockViewModel: ObservableObject {
    public static let shared = DockViewModel()
    
    // Core Managers
    public let multitouchManager = MultitouchManager.shared
    public let windowController = GlassWindowController()
    public let permissionManager = PermissionManager.shared
    
    // Services
    public let clipboardService = ClipboardMonitorService.shared
    public let mediaService = MediaService.shared
    public let calendarService = CalendarService.shared
    public let wallpaperService = WallpaperService.shared
    public let appLauncher = AppLauncherService.shared
    public let folderService = FolderService.shared
    public let statsService = SystemStatsService.shared
    public let weatherService = WeatherService.shared
    public let checklistService = ChecklistService.shared
    public let promptService = PromptLibraryService.shared
    public let audioPipeline = AudioRecordingPipeline.shared
    public let transcriptionService = SpeechTranscriptionService.shared
    
    // UI State
    @Published public var isVoiceModeActive: Bool = false
    @Published public var liveVoiceTranscript: String = ""
    @Published public var aiPromptInput: String = ""
    @Published public var conversationHistory: [AIMessage] = []
    @Published public var isAIStreaming: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // AI modes and memory
    public let aiSettings = AIAssistantSettings.shared
    public let aiMemory = AIMemoryStore.shared
    private let appTracker = FrontmostAppTracker.shared
    private var aiService: AIServiceProtocol = AppleIntelligenceService()
    
    public init() {
        bindGestureEngine()
        updateAIService()
        
        windowController.onDismiss = { [weak self] in
            self?.multitouchManager.stateMachine.resetToIdle()
        }
    }
    
    public func start() {
        multitouchManager.start()
    }
    
    public func updateAIService() {
        let providerName = UserDefaults.standard.string(forKey: "ai_provider") ?? AIProvider.appleIntelligence.rawValue
        
        if providerName == AIProvider.openAI.rawValue {
            let key = UserDefaults.standard.string(forKey: "openai_key") ?? ""
            if !key.isEmpty {
                self.aiService = OpenAIService(apiKey: key)
                return
            }
        } else if providerName == AIProvider.gemini.rawValue {
            let key = UserDefaults.standard.string(forKey: "gemini_key") ?? ""
            if !key.isEmpty {
                self.aiService = GeminiService(apiKey: key)
                return
            }
        } else if providerName == AIProvider.ollama.rawValue {
            let host = UserDefaults.standard.string(forKey: "ollama_host") ?? "http://localhost:11434"
            self.aiService = LocalOllamaService(host: host)
            return
        } else if providerName == AIProvider.mock.rawValue {
            self.aiService = MockAIService()
            return
        }
        
        // Default to Apple Intelligence Foundation Model
        self.aiService = AppleIntelligenceService()
    }
    
    private func bindGestureEngine() {
        // currentState is already published on the main thread, so skip the extra
        // .receive(on:) hop that added a frame of delay to every swipe update.
        multitouchManager.$currentState
            .sink { [weak self] state in
                self?.handleGestureState(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleGestureState(_ state: GestureDockState) {
        switch state {
        case .trackingLeftSwipe(let progress, _):
            let isPastHalf = progress >= 0.50
            if isPastHalf && !isVoiceModeActive {
                self.isVoiceModeActive = true
            }
            windowController.updateInteractiveProgress(progress, mode: isVoiceModeActive ? .expandedVoice : .standardDock)
            
        case .trackingTopSwipe(let progress, _):
            self.isVoiceModeActive = true
            windowController.updateInteractiveProgress(progress, mode: .expandedVoice)
            
        case .dockRevealed(let mode):
            multitouchManager.stateMachine.isDockOpen = true
            self.isVoiceModeActive = (mode == .expandedVoice)
            windowController.present(mode: mode, animated: true)
            if mode == .expandedVoice {
                startVoiceRecording()
            }
            
        case .dockDismissed, .cancelled:
            multitouchManager.stateMachine.isDockOpen = false
            self.isVoiceModeActive = false
            stopVoiceRecording()
            windowController.dismiss(animated: true)
            
        case .voiceModeActive:
            multitouchManager.stateMachine.isDockOpen = true
            self.isVoiceModeActive = true
            windowController.present(mode: .expandedVoice, animated: true)
            startVoiceRecording()
            
        case .idle:
            break
        }
    }
    
    public func toggleStandardDock() {
        if windowController.isVisible && !isVoiceModeActive {
            multitouchManager.stateMachine.resetToIdle()
            windowController.dismiss()
        } else {
            isVoiceModeActive = false
            multitouchManager.stateMachine.isDockOpen = true
            windowController.present(mode: .standardDock)
        }
    }
    
    public func toggleVoiceMode() {
        if windowController.isVisible && isVoiceModeActive {
            stopVoiceRecordingAndSend()
            multitouchManager.stateMachine.resetToIdle()
            windowController.dismiss()
        } else {
            isVoiceModeActive = true
            multitouchManager.stateMachine.isDockOpen = true
            windowController.present(mode: .expandedVoice)
            startVoiceRecording()
        }
    }
    
    public func startVoiceRecording() {
        liveVoiceTranscript = ""
        let recording = audioPipeline.startRecording()
        
        if let format = recording.inputFormat {
            transcriptionService.startLiveRecognition(
                inputFormat: format,
                onPartialResult: { [weak self] partialText in
                    self?.liveVoiceTranscript = partialText
                },
                onSilenceAutoSend: { [weak self] finalText in
                    self?.handleVoiceAutoSend(finalText)
                }
            )
        }
    }
    
    public func stopVoiceRecording() {
        _ = audioPipeline.stopRecording()
        transcriptionService.stopLiveRecognition()
    }
    
    private func handleVoiceAutoSend(_ text: String) {
        stopVoiceRecording()
        
        let prompt = text.isEmpty ? liveVoiceTranscript : text
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        sendAIMessage(prompt)
    }
    
    public func stopVoiceRecordingAndSend() {
        let text = liveVoiceTranscript
        stopVoiceRecording()
        
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sendAIMessage(text)
        }
    }
    
    public func sendAIMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let previousMessages = conversationHistory
        let userMessage = AIMessage(role: .user, content: text)
        conversationHistory.append(userMessage)
        
        let assistantMessageID = UUID()
        conversationHistory.append(AIMessage(id: assistantMessageID, role: .assistant, content: ""))
        
        isAIStreaming = true
        updateAIService()
        let instructions = aiSettings.modeInstructions()
        let context = buildAIContext(for: text)
        let rememberThis = aiSettings.memoryEnabled && aiSettings.memoryConsentGiven
        
        Task {
            var reply = ""
            do {
                let stream = aiService.sendMessageStream(prompt: text, conversationHistory: previousMessages, instructions: instructions, turnContext: context)
                for try await chunk in stream {
                    reply += chunk
                    await MainActor.run {
                        if let index = self.conversationHistory.firstIndex(where: { $0.id == assistantMessageID }) {
                            self.conversationHistory[index].content += chunk
                        }
                    }
                }
            } catch {
                reply = ""
                await MainActor.run {
                    if let index = self.conversationHistory.firstIndex(where: { $0.id == assistantMessageID }) {
                        self.conversationHistory[index].content = "⚠️ Error: \(error.localizedDescription)"
                    }
                }
            }
            
            reply = Self.cleanReply(reply)
            await MainActor.run {
                // The on-device model sometimes adds markdown bold markers; the chat shows plain text.
                if let index = self.conversationHistory.firstIndex(where: { $0.id == assistantMessageID }),
                   !self.conversationHistory[index].content.hasPrefix("⚠️") {
                    self.conversationHistory[index].content = Self.cleanReply(self.conversationHistory[index].content)
                }
                self.isAIStreaming = false
                // Memory keeps both sides: what you asked and what the AI said.
                if rememberThis && !reply.isEmpty {
                    self.aiMemory.record(user: text, assistant: reply)
                }
            }
        }
    }
    
    static func cleanReply(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Background for this one message: the time, relevant memories (if memory is on),
    /// and what's on the Mac (Computer mode, only what's allowed).
    private func buildAIContext(for text: String) -> String {
        var parts = [AIAssistantSettings.nowLine()]
        
        if aiSettings.memoryEnabled && aiSettings.memoryConsentGiven {
            let memories = aiMemory.contextBlock(for: text)
            if !memories.isEmpty { parts.append(memories) }
        }
        
        if aiSettings.mode == .computer {
            if aiSettings.isAllowed(.dock) { parts.append(dockSnapshot()) }
            if aiSettings.isAllowed(.currentApp), let app = appTracker.appDescription() {
                parts.append("They were just using: \(app)")
            }
            if aiSettings.isAllowed(.selectedText), let selected = appTracker.selectedText() {
                parts.append("Text they have highlighted in that app:\n\"\"\"\n\(selected)\n\"\"\"")
            }
        }
        // Keep it small enough for the on-device model.
        return String(parts.joined(separator: "\n\n").prefix(6000))
    }
    
    /// A short summary of the dock's contents for Computer mode.
    private func dockSnapshot() -> String {
        var lines = ["What's in their Master Dock right now:"]
        
        let time = DateFormatter()
        time.dateFormat = "h:mm a"
        let events = calendarService.todayEvents.prefix(8).map { event -> String in
            event.isAllDay ? "\(event.title) (all day)" : "\(event.title) \(time.string(from: event.startDate))-\(time.string(from: event.endDate))"
        }
        lines.append("Today's events: " + (events.isEmpty ? "none" : events.joined(separator: "; ")))
        
        if let track = mediaService.currentTrack {
            lines.append("Music: \(mediaService.isPlaying ? "playing" : "paused") \"\(track.title)\" by \(track.artist)")
        }
        
        let todos = checklistService.items.prefix(10).map { "\($0.isCompleted ? "[done]" : "[ ]") \($0.title)" }
        if !todos.isEmpty { lines.append("Checklist: " + todos.joined(separator: "; ")) }
        
        let notes = (UserDefaults.standard.string(forKey: "quick_notes_text") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { lines.append("Quick notes: " + AIMemoryStore.clip(notes, 500)) }
        
        let clips = clipboardService.items.prefix(5).compactMap { item -> String? in
            guard let text = item.textContent else { return item.type == .image ? "(an image)" : nil }
            return "\"" + AIMemoryStore.clip(text.replacingOccurrences(of: "\n", with: " "), 160) + "\""
        }
        if !clips.isEmpty { lines.append("Recently copied (newest first): " + clips.joined(separator: "; ")) }
        
        return lines.joined(separator: "\n")
    }
    
    public func clearConversation() {
        conversationHistory.removeAll()
    }
}
