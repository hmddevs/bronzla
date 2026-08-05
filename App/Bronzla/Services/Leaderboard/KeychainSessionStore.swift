import Foundation
import OSLog
import Security

/// Persists the current `LeaderboardSession` in the Keychain.
///
/// A session token is a credential, not app data: it must survive across launches like
/// `UserDefaults` would give it, but it must not sit in a plist an unsandboxed inspection of the
/// device could read, and it must not be SwiftData, which is on-disk unencrypted by default.
/// The Keychain Services API is the only right place for it.
///
/// Stored with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` rather than the non-"this
/// device" variant: nothing depends on the session restoring itself onto a different device from
/// an encrypted backup, and keeping it device-local is the safer default for a credential.
struct KeychainSessionStore: Sendable {
    private let service = "com.hmdcorp.bronzla.leaderboard"
    private let account = "session"
    private let logger = Logger(subsystem: "com.hmdcorp.bronzla", category: "KeychainSessionStore")

    /// Writes the session to the Keychain. Returns `false` on an encoding or Keychain-write
    /// failure so a caller can react (or at least know) rather than silently leaving the user
    /// appearing signed in for the rest of the session but signed out again on next launch.
    @discardableResult
    func save(_ session: LeaderboardSession) -> Bool {
        guard let data = try? JSONEncoder().encode(session) else {
            logger.error("Failed to encode leaderboard session for Keychain storage.")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain write for leaderboard session failed with status \(status).")
            return false
        }
        return true
    }

    func load() -> LeaderboardSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(LeaderboardSession.self, from: data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
