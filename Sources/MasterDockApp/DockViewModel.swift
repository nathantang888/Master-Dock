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
        multitouchManager.$currentState
            .receive(on: DispatchQueue.main)
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
        
        let userMessage = AIMessage(role: .user, content: text)
        conversationHistory.append(userMessage)
        
        let assistantMessageID = UUID()
        let assistantMessage = AIMessage(id: assistantMessageID, role: .assistant, content: "")
        conversationHistory.append(assistantMessage)
        
        isAIStreaming = true
        updateAIService()
        
        Task {
            do {
                let stream = aiService.sendMessageStream(prompt: text, conversationHistory: conversationHistory.dropLast())
                for try await chunk in stream {
                    await MainActor.run {
                        if let index = self.conversationHistory.firstIndex(where: { $0.id == assistantMessageID }) {
                            self.conversationHistory[index].content += chunk
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if let index = self.conversationHistory.firstIndex(where: { $0.id == assistantMessageID }) {
                        self.conversationHistory[index].content = "⚠️ Error: \(error.localizedDescription)"
                    }
                }
            }
            
            await MainActor.run {
                self.isAIStreaming = false
            }
        }
    }
    
    public func clearConversation() {
        conversationHistory.removeAll()
    }
}
