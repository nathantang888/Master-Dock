import Foundation

public enum AIProvider: String, Codable, CaseIterable, Sendable {
    case appleIntelligence = "Apple Intelligence (Foundation Model)"
    case openAI = "OpenAI (GPT-4o)"
    case gemini = "Google Gemini"
    case ollama = "Local Ollama"
    case mock = "Instant Preview (Mock)"
}

public struct AIMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let role: Role
    public var content: String
    public let timestamp: Date
    
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }
    
    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public protocol AIServiceProtocol: AnyObject, Sendable {
    var provider: AIProvider { get }
    func sendMessageStream(prompt: String, conversationHistory: [AIMessage]) -> AsyncThrowingStream<String, Error>
    /// Same as above plus background instructions (AI mode, memories, what's on the Mac).
    func sendMessageStream(prompt: String, conversationHistory: [AIMessage], systemContext: String) -> AsyncThrowingStream<String, Error>
    /// Steady chat instructions plus background that only applies to this one message.
    func sendMessageStream(prompt: String, conversationHistory: [AIMessage], instructions: String, turnContext: String) -> AsyncThrowingStream<String, Error>
}

public extension AIServiceProtocol {
    /// Default: providers without separate instructions get the context in front of the message.
    func sendMessageStream(prompt: String, conversationHistory: [AIMessage], systemContext: String) -> AsyncThrowingStream<String, Error> {
        let context = systemContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty else { return sendMessageStream(prompt: prompt, conversationHistory: conversationHistory) }
        return sendMessageStream(prompt: "\(context)\n\nUser's message:\n\(prompt)", conversationHistory: conversationHistory)
    }
    
    /// Default: everything becomes one block of context.
    func sendMessageStream(prompt: String, conversationHistory: [AIMessage], instructions: String, turnContext: String) -> AsyncThrowingStream<String, Error> {
        let combined = [instructions, turnContext].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return sendMessageStream(prompt: prompt, conversationHistory: conversationHistory, systemContext: combined)
    }
}
