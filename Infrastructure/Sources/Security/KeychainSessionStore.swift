#if canImport(Core)
import Core
#endif
import Foundation
#if canImport(Security)
import Security
#endif

public actor KeychainSessionStore: SessionStoring {
    private let account: String
    private let encoder = JSONCoder.encoder()
    private let decoder = JSONCoder.decoder()
    private let service: String

    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.example.fitnesscoach",
        account: String = "auth.session"
    ) {
        self.service = service
        self.account = account
    }

    public func loadSession() async throws -> AuthSession? {
        #if canImport(Security)
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                return nil
            }
            return try decoder.decode(AuthSession.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw AppError.unavailable("Unable to access the secure session store.")
        }
        #else
        return nil
        #endif
    }

    public func saveSession(_ session: AuthSession) async throws {
        #if canImport(Security)
        let data = try encoder.encode(session)
        var query = baseQuery
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributes = [kSecValueData as String: data] as CFDictionary
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes)
            guard updateStatus == errSecSuccess else {
                throw AppError.unavailable("Unable to update the secure session store.")
            }
            return
        }

        guard status == errSecSuccess else {
            throw AppError.unavailable("Unable to save the secure session.")
        }
        #endif
    }

    public func clearSession() async throws {
        #if canImport(Security)
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.unavailable("Unable to clear the secure session.")
        }
        #endif
    }
}

#if canImport(Security)
private extension KeychainSessionStore {
    var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
#endif
