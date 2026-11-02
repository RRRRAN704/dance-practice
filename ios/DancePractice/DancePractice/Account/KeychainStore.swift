//
//  KeychainStore.swift
//  DancePractice
//

import Foundation
import Security

/// Saves small secrets (the login tokens) in the iOS Keychain instead of UserDefaults,
/// which is a plain file anyone with a device backup could read.
struct KeychainStore {
    let service: String

    func data(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func set(_ data: Data, for key: String) {
        // Delete-then-add is simpler than SecItemUpdate and the item is tiny.
        delete(key)
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        // Readable after the first unlock, so a sync can run while the phone is locked.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func delete(_ key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
