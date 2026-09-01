import Foundation
import AppKit
import MasterDockServices

final class ClipboardMonitorTests {
    func testClipboardItemCreation() {
        let item = ClipboardItem(
            type: .text,
            textContent: "Master Dock Productivity Suite",
            previewTitle: "Master Dock Productivity Suite",
            previewSubtitle: "30 chars"
        )
        
        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.textContent, "Master Dock Productivity Suite")
        XCTAssertFalse(item.id.uuidString.isEmpty)
    }
    
    func testClipboardTypeClassification() {
        let codeSnippet = "func calculateSum(a: Int, b: Int) -> Int { return a + b }"
        let urlSnippet = "https://apple.com/macos"
        let colorHex = "#FF5733"
        let plainText = "Meeting notes for quarterly sync"
        
        XCTAssertTrue(codeSnippet.contains("func "))
        XCTAssertTrue(urlSnippet.starts(with: "https://"))
        XCTAssertTrue(colorHex.hasPrefix("#") && colorHex.count == 7)
        XCTAssertFalse(plainText.starts(with: "http"))
    }
}
