import Foundation
import AppKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Real Apple Intelligence Foundation Model Service
/// Uses Apple's native on-device Large Language Model (`FoundationModels` framework)
/// for zero-latency, private, high-performance neural language generation on Apple Silicon.
public final class AppleIntelligenceService: AIServiceProtocol, @unchecked Sendable {
    public let provider: AIProvider = .appleIntelligence
    
    #if canImport(FoundationModels)
    private var sessionStorage: Any?
    
    @available(macOS 26.0, *)
    private var session: LanguageModelSession? {
        get { sessionStorage as? LanguageModelSession }
        set { sessionStorage = newValue }
    }
    #endif
    
    public init() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if SystemLanguageModel.default.isAvailable {
                self.sessionStorage = LanguageModelSession(
                    instructions: """
                    You are Master Dock AI, an ultra-fast, intelligent, and helpful macOS desktop companion powered natively by Apple Intelligence.
                    Provide concise, accurate, well-formatted answers with markdown, bullet points, and code blocks when appropriate.
                    """
                )
            }
        }
        #endif
    }
    
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    continuation.finish()
                    return
                }
                
                #if canImport(FoundationModels)
                if #available(macOS 26.0, *) {
                    if SystemLanguageModel.default.isAvailable {
                        do {
                            // Initialize session or use configured session
                            let activeSession = self.session ?? LanguageModelSession(
                                instructions: "You are Master Dock AI, a helpful macOS desktop assistant powered by Apple Intelligence."
                            )
                            
                            var previousLength = 0
                            let stream = activeSession.streamResponse(to: trimmed)
                            
                            for try await snapshot in stream {
                                let currentContent = snapshot.content
                                if currentContent.count > previousLength {
                                    let delta = String(currentContent.dropFirst(previousLength))
                                    continuation.yield(delta)
                                    previousLength = currentContent.count
                                }
                            }
                            
                            continuation.finish()
                            return
                        } catch {
                            print("[AppleIntelligenceService] Real-time inference error: \(error)")
                        }
                    }
                }
                #endif
                
                // Fallback response if on-device model is unavailable
                let fallback = "Hello! I am Master Dock AI running natively on macOS. How can I assist you?"
                continuation.yield(fallback)
                continuation.finish()
            }
        }
    }
}
