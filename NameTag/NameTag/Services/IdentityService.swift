import Foundation
import Security

@Observable
final class IdentityService {
    private(set) var currentUID: String
    private static let keychainKey = "com.nametag.userUID"
    private static let onboardedKey = "isOnboarded"

    var isOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardedKey) }
    }

    init() {
        if let existing = Self.loadFromKeychain() {
            currentUID = existing
        } else {
            let uid = UUID().uuidString
            Self.saveToKeychain(uid)
            currentUID = uid
        }
    }

    func resetIdentity() {
        Self.deleteFromKeychain()
        let newUID = UUID().uuidString
        Self.saveToKeychain(newUID)
        currentUID = newUID
        isOnboarded = false
    }

    // MARK: - Keychain

    private static func saveToKeychain(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
