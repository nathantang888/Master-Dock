import Foundation
import MasterDockAI

/// Memory recall, including the "house" example: day 1 you ask about a house, day 5 you ask
/// "how much was the house?" and it remembers what it told you.
public struct AIMemoryTests {
    public init() {}
    
    private func freshStore() -> AIMemoryStore {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("md_memory_\(UUID().uuidString).json")
        return AIMemoryStore(fileURL: url)
    }
    
    public func testRemembersTheHouseDaysLater() {
        let memory = freshStore()
        let day1 = Date().addingTimeInterval(-4 * 86_400)
        memory.record(user: "How much would a 3 bedroom house in San Jose cost?", assistant: "A 3 bedroom house in San Jose is around $1.6 million right now.", date: day1)
        memory.record(user: "Explain derivatives", assistant: "A derivative measures how fast something changes.", date: day1)
        memory.record(user: "What's a good pasta recipe?", assistant: "Try garlic butter pasta.", date: day1)
        
        let found = memory.relevant(to: "how much was the house?")
        XCTAssertEqual(found.first?.user ?? "", "How much would a 3 bedroom house in San Jose cost?")
        let block = memory.contextBlock(for: "how much was the house?")
        XCTAssertTrue(block.contains("1.6 million"), "the AI's own answer is included")
    }
    
    public func testMemorySurvivesRestartAndCanBeForgotten() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("md_memory_\(UUID().uuidString).json")
        let first = AIMemoryStore(fileURL: url)
        first.record(user: "My locker code is 12-30-5", assistant: "Got it, I'll remember your locker code.")
        let reopened = AIMemoryStore(fileURL: url)
        XCTAssertEqual(reopened.exchanges.count, 1)
        reopened.forgetAll()
        XCTAssertEqual(AIMemoryStore(fileURL: url).exchanges.count, 0)
    }
    
    public func testUnrelatedQuestionsDontPullMemories() {
        let memory = freshStore()
        memory.record(user: "How much would a house cost?", assistant: "About $1.6 million.")
        XCTAssertTrue(memory.relevant(to: "what's the weather like").isEmpty)
    }
    
    public func testModeInstructions() {
        let suite = UserDefaults(suiteName: "md_ai_\(UUID().uuidString)")!
        let settings = AIAssistantSettings(defaults: suite)
        settings.mode = .personal
        settings.preferredName = "Nathan"
        XCTAssertTrue(settings.modeInstructions().contains("Nathan"))
        settings.mode = .generic
        XCTAssertFalse(settings.modeInstructions().contains("Nathan"), "General mode never uses personal info")
    }
}
