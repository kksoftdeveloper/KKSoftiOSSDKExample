//
//  KeychainManager.swift
//  AuthSDKExample
//
//  Created by Andy on 4/18/25.
//
import Foundation

@objc public class KeychainManagerObjCBridge: NSObject {
    @MainActor @objc public static let shared = KeychainManagerObjCBridge()
    private override init() {}  // Use override when subclassing NSObject
    
    @objc public func save(_ data: NSData, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     key,
            kSecValueData as String:       data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    @objc public func load(forKey key: String) -> NSData? {
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     key,
            kSecReturnData as String:      true,
            kSecMatchLimit as String:      kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject? = nil
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess else { return nil }
        return dataTypeRef as? NSData
    }
    
    @objc public func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Auth Session (JSON)
    
    private var sessionKey: String { "authSession" }
    
    // Save NSDictionary (converted to Data) for AuthSessionResponse
    @objc public func saveAuthSessionDict(_ dict: NSDictionary) {
        do {
            // Ensure all values are JSON-serializable (convert NSNumber to String if needed)
            var cleanedDict: [String: Any] = [:]
            for (key, value) in dict {
                if let stringKey = key as? String {
                    // Convert NSNumber to String for consistency
                    if let number = value as? NSNumber {
                        cleanedDict[stringKey] = number.stringValue
                    } else {
                        cleanedDict[stringKey] = value
                    }
                }
            }
            
            if let data = try JSONSerialization.data(withJSONObject: cleanedDict, options: []) as NSData? {
                save(data, forKey: sessionKey)
                debugPrint("[KeychainManagerObjCBridge] ✅ Successfully saved auth session")
            } else {
                debugPrint("[KeychainManagerObjCBridge] ❌ Failed to serialize dictionary to JSON")
            }
        } catch {
            debugPrint("[KeychainManagerObjCBridge] ❌ Error saving auth session: \(error)")
        }
    }
    
    // Load NSDictionary for AuthSessionResponse
    @objc public func loadAuthSessionDict() -> NSDictionary? {
        guard let data = load(forKey: sessionKey) as Data? else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? NSDictionary
    }
    
    @objc public func clearAuthSession() {
        delete(forKey: sessionKey)
    }
}
