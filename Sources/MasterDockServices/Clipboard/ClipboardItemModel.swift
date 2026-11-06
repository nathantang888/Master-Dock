import Foundation
import AppKit

public enum ClipboardContentType: String, Codable, Sendable {
    case text
    case image
    case url
    case code
    case color

    public static func classify(string: String) -> ClipboardContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .url
        }
        if (trimmed.hasPrefix("#") && (trimmed.count == 7 || trimmed.count == 9)) ||
           trimmed.hasPrefix("rgb(") || trimmed.hasPrefix("rgba(") {
            return .color
        }
        if trimmed.contains("func ") || trimmed.contains("class ") || trimmed.contains("import ") ||
           trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("var ") ||
           trimmed.contains("def ") || trimmed.contains("return ") || trimmed.contains("{") {
            return .code
        }
        return .text
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: ClipboardContentType
    public let textContent: String?
    public let imageData: Data?
    public let previewTitle: String
    public let previewSubtitle: String
    /// Pinned items stay at the top, are never trimmed, and survive "Clear".
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardContentType,
        textContent: String? = nil,
        imageData: Data? = nil,
        previewTitle: String,
        previewSubtitle: String,
        isPinned: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
        self.previewTitle = previewTitle
        self.previewSubtitle = previewSubtitle
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, type, textContent, imageData, previewTitle, previewSubtitle, isPinned
    }

    /// History saved by older versions has no `isPinned`; those items load as unpinned.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        type = try c.decode(ClipboardContentType.self, forKey: .type)
        textContent = try c.decodeIfPresent(String.self, forKey: .textContent)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        previewTitle = try c.decode(String.self, forKey: .previewTitle)
        previewSubtitle = try c.decode(String.self, forKey: .previewSubtitle)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}
