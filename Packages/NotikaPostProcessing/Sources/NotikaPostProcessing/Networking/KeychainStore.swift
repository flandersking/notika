import Foundation
import Security
import NotikaCore

public enum KeychainProvider: String, Sendable {
    case anthropic
    case openAI
    case google
}

public enum KeychainStore {
    private static func service(for provider: KeychainProvider) -> String {
        "app.notika.apikey.\(provider.rawValue)"
    }

    public static func setKey(_ key: String?, for provider: KeychainProvider) {
        let svc = service(for: provider)
        // Vorhandenen Eintrag löschen
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let key, !key.isEmpty, let data = key.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    public static func key(for provider: KeychainProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
