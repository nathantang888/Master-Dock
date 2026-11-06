import Foundation
import Security

/// Stores secrets (API keys) in the macOS Keychain, the same encrypted place macOS keeps
/// passwords, instead of plain text in the app's preferences file.
public enum KeychainStore {
    private static let service = "com.masterdock.app"

    /// Names of the secrets the app keeps. They used to live in UserDefaults.
    public static let openAIKey = "openai_key"
    public static let geminiKey = "gemini_key"

    public static func string(for account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves a secret. An empty value deletes it.
    @discardableResult
    public static func set(_ value: String, for account: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete(account) }
        let data = Data(trimmed.utf8)

        let update = [kSecValueData as String: data] as CFDictionary
        let status = SecItemUpdate(baseQuery(account) as CFDictionary, update)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        var add = baseQuery(account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        add[kSecAttrLabel as String] = "Master Dock \(account)"
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    public static func delete(_ account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Moves keys saved by older versions out of the plain-text preferences file.
    public static func migrateFromUserDefaults(_ defaults: UserDefaults = .standard) {
        for account in [openAIKey, geminiKey] {
            guard let old = defaults.string(forKey: account) else { continue }
            if !old.isEmpty, string(for: account) == nil {
                set(old, for: account)
            }
            // Only erase the old copy once it's safely in the Keychain (or it was empty).
            if old.isEmpty || string(for: account) != nil {
                defaults.removeObject(forKey: account)
            }
        }
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
