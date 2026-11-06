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
    
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage], systemContext: String) -> AsyncThrowingStream<String, Error> {
        sendMessageStream(prompt: prompt, conversationHistory: conversationHistory, instructions: systemContext, turnContext: "")
    }
    
    /// Keeps one real chat session going, so the model remembers the whole conversation
    /// instead of re-reading a pasted copy of it each time (which made it repeat itself).
    public func sendMessageStream(prompt: String, conversationHistory: [AIMessage], instructions: String, turnContext: String) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), SystemLanguageModel.default.isAvailable {
            return AsyncThrowingStream { continuation in
                Task {
                    let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continuation.finish(); return }
                    
                    let baseInstructions = instructions.isEmpty
                        ? "You are Master Dock AI, a friendly assistant built into a Mac dock app."
                        : instructions
                    let request = Self.composeRequest(message: trimmed, turnContext: turnContext)
                    let previous = conversationHistory.filter { $0.role != .system && !$0.content.isEmpty && !$0.content.hasPrefix("⚠️") }
                    let cache = AppleChatSessionCache.shared
                    
                    for attempt in 0..<2 {
                        let session: LanguageModelSession
                        if attempt == 0,
                           let existing = cache.session(instructions: baseInstructions, historyCount: conversationHistory.count) as? LanguageModelSession {
                            session = existing
                        } else {
                            // New chat, or the app restarted, or the chat got too long: start a session
                            // that already knows the recent conversation.
                            session = LanguageModelSession(instructions: Self.seeded(baseInstructions, previous: previous, compact: attempt > 0))
                        }
                        
                        var sentLength = 0
                        do {
                            for try await snapshot in session.streamResponse(to: request) {
                                let current = snapshot.content
                                if current.count > sentLength {
                                    continuation.yield(String(current.dropFirst(sentLength)))
                                    sentLength = current.count
                                }
                            }
                            // The app's history will have this message and the reply added.
                            cache.store(session, instructions: baseInstructions, historyCount: conversationHistory.count + 2)
                            continuation.finish()
                            return
                        } catch {
                            cache.reset()
                            // Retry once with a shorter history (usually the chat got too long),
                            // but never after part of a reply was already shown.
                            if attempt == 1 || sentLength > 0 {
                                continuation.finish(throwing: error)
                                return
                            }
                        }
                    }
                }
            }
        }
        #endif
        let combined = [instructions, turnContext].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return sendMessageStream(prompt: combined.isEmpty ? prompt : "\(combined)\n\nMessage:\n\(prompt)", conversationHistory: conversationHistory)
    }
    
    static func composeRequest(message: String, turnContext: String) -> String {
        let context = turnContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty else { return message }
        return "[Background for this message:\n\(context)]\n\n\(message)"
    }
    
    static func seeded(_ instructions: String, previous: [AIMessage], compact: Bool) -> String {
        let recent = previous.suffix(compact ? 4 : 10)
        guard !recent.isEmpty else { return instructions }
        var text = instructions + "\n\nThe conversation so far (keep going from here, and don't repeat these replies):"
        for message in recent {
            let who = message.role == .user ? "They said" : "You said"
            text += "\n\(who): \(String(message.content.prefix(compact ? 250 : 500)))"
        }
        return text
    }
}

/// Holds the current chat session between messages. The service object itself gets
/// recreated often, so the session lives here.
final class AppleChatSessionCache: @unchecked Sendable {
    static let shared = AppleChatSessionCache()
    private let lock = NSLock()
    private var session: AnyObject?
    private var instructions = ""
    private var historyCount = -1
    
    func session(instructions: String, historyCount: Int) -> AnyObject? {
        lock.lock(); defer { lock.unlock() }
        guard self.instructions == instructions, self.historyCount == historyCount else { return nil }
        return session
    }
    
    func store(_ session: AnyObject, instructions: String, historyCount: Int) {
        lock.lock(); defer { lock.unlock() }
        self.session = session
        self.instructions = instructions
        self.historyCount = historyCount
    }
    
    func reset() {
        lock.lock(); defer { lock.unlock() }
        session = nil
        historyCount = -1
    }
}

