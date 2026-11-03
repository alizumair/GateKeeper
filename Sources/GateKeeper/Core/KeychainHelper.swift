import Foundation
import Security
import CryptoKit

/// Wrapper around macOS Keychain for storing sensitive credentials securely.
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let service = "com.gatekeeper.app.master"
    private let saltAccount = "GateKeeperSalt"
    
    private init() {}
    
    // MARK: - Generic Keychain Operations
    
    public func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Remove existing item if any
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return data
        }
        return nil
    }
    
    public func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Passcode & Salt Helpers
    
    public func getOrCreateSalt() -> Data {
        if let existingSalt = read(key: saltAccount) {
            return existingSalt
        }
        
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let newSalt = Data(bytes)
        _ = save(key: saltAccount, data: newSalt)
        return newSalt
    }
    
    public func hashPasscode(_ passcode: String) -> String {
        let salt = getOrCreateSalt()
        var saltedData = Data(passcode.utf8)
        saltedData.append(salt)
        let digest = SHA256.hash(data: saltedData)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
