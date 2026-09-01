import Foundation
import MasterDockAI

final class AIServiceMockTests {
    func testMockAIServiceStreaming() async throws {
        let mockService = MockAIService()
        let stream = mockService.sendMessageStream(prompt: "Summarize this article", conversationHistory: [])
        
        var accumulated = ""
        for try await chunk in stream {
            accumulated += chunk
        }
        
        XCTAssertFalse(accumulated.isEmpty)
        XCTAssertTrue(accumulated.contains("summary") || accumulated.contains("Summary") || accumulated.contains("Theme"))
    }
    
    func testAppleIntelligenceStreaming() async throws {
        let aiService = AppleIntelligenceService()
        let stream = aiService.sendMessageStream(prompt: "Hello! Reply with a short greeting.", conversationHistory: [])
        
        var accumulated = ""
        for try await chunk in stream {
            accumulated += chunk
        }
        
        XCTAssertFalse(accumulated.isEmpty)
    }
    
    func testPromptTemplateResolution() {
        let promptService = PromptLibraryService()
        let summarizeAction = PromptAction(
            title: "Summarize",
            iconSystemName: "doc.plaintext",
            promptTemplate: "Summarize the following:\n\n{clipboard}"
        )
        
        let resolved = promptService.resolvePrompt(summarizeAction, clipboardContent: "Apple releases macOS Sequoia with enhanced continuity.")
        XCTAssertTrue(resolved.contains("Apple releases macOS Sequoia"))
        XCTAssertFalse(resolved.contains("{clipboard}"))
    }
}
