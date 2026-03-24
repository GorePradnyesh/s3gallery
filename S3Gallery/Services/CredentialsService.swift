import Foundation
import Security

protocol CredentialsServiceProtocol {
    func save(_ credentials: Credentials) throws
    func load() throws -> Credentials?
    func delete() throws
}

enum CredentialsServiceError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save credentials (OSStatus \(status))."
        case .loadFailed(let status):
            return "Failed to load credentials (OSStatus \(status))."
        case .deleteFailed(let status):
            return "Failed to delete credentials (OSStatus \(status))."
        case .decodingFailed:
            return "Failed to decode stored credentials."
        }
    }
}

final class CredentialsService: CredentialsServiceProtocol {
    private let keychainService = "com.personal.s3gallery"
    private let keychainAccount = "aws-credentials"

    func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: data
        ]

        // Delete any existing entry first
        SecItemDelete(attributes as CFDictionary)

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialsServiceError.saveFailed(status)
        }
    }

    func load() throws -> Credentials? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CredentialsServiceError.loadFailed(status)
        }

        do {
            return try JSONDecoder().decode(Credentials.self, from: data)
        } catch {
            throw CredentialsServiceError.decodingFailed
        }
    }

    func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialsServiceError.deleteFailed(status)
        }
    }
}
