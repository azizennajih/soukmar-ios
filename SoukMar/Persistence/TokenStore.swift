import Foundation
import Security

/// Keychain-backed session store — the iOS-idiomatic equivalent of
/// soukmar-android's DataStore-backed TokenManager. Stores the JWT plus a
/// light user snapshot so the app can restore a logged-in state on launch
/// without an extra network round trip.
final class TokenStore {
    static let shared = TokenStore()

    private let service = "com.soukmar.app.session"
    private let tokenKey = "token"
    private let userDefaultsKey = "com.soukmar.app.cachedUser"

    var token: String? {
        get { readKeychain(tokenKey) }
        set {
            if let newValue {
                writeKeychain(tokenKey, value: newValue)
            } else {
                deleteKeychain(tokenKey)
            }
        }
    }

    var isLoggedIn: Bool { token != nil }

    var cachedUser: UserDto? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
            return try? JSONDecoder().decode(UserDto.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                return
            }
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func saveSession(token: String, user: UserDto) {
        self.token = token
        self.cachedUser = user
    }

    func clear() {
        token = nil
        cachedUser = nil
    }

    // MARK: - Keychain plumbing

    private func readKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func writeKeychain(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func deleteKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
