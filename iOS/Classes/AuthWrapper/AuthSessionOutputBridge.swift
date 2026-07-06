//
//  AuthSessionOutputBridge.swift
//  UnityFramework
//
//  Created by Admin on 11/4/25.
//

import Foundation

@objc public class AuthSessionOutputBridge: NSObject {
    
    /// Generic method to convert any Codable Swift struct to NSDictionary
    /// Works with AuthSessionOutput and any other Codable type
    @objc public static func convertCodableToDictionary(_ output: Any) -> NSDictionary? {
        // Try to encode as JSON if it's Codable
        guard output is any Encodable else {
            return nil
        }
        
        // Use reflection to encode - but simpler: use JSONEncoder
        // Since Swift structs that are Codable can be encoded
        do {
            _ = JSONEncoder()
            // Use reflection to encode
            let mirror = Mirror(reflecting: output)
            var dict: [String: Any] = [:]
            
            for child in mirror.children {
                if let label = child.label {
                    dict[label] = child.value
                }
            }
            
            // If we got a dictionary, return it
            if !dict.isEmpty {
                // Convert values to strings if needed for compatibility
                var result: [String: Any] = [:]
                for (key, value) in dict {
                    // Handle the CodingKeys mapping
                    let mappedKey: String
                    switch key {
                    case "gameUUID":
                        mappedKey = "gameUID"  // AuthSessionOutput uses "gameUID" in CodingKeys
                    default:
                        mappedKey = key
                    }
                    result[mappedKey] = value
                }
                return result as NSDictionary
            }
        }
        
        return nil
    }
    
    /// Extract from notification object and convert using JSON encoding
    @objc public static func extractFromNotification(_ notification: Notification) -> NSDictionary? {
        guard let object = notification.object else {
            debugPrint("[AuthSessionOutputBridge] Notification object is nil")
            return nil
        }
        
        debugPrint("[AuthSessionOutputBridge] Extracting from object: \(object)")
        debugPrint("[AuthSessionOutputBridge] Object type: \(type(of: object))")
        
        // Try to use JSON encoding if it's Codable
        // Since AuthSessionOutput is Codable, we can encode it to JSON and decode as dictionary
        if let codable = object as? any Codable {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(codable)
                debugPrint("[AuthSessionOutputBridge] Encoded to JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
                
                if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    debugPrint("[AuthSessionOutputBridge] Successfully converted to dictionary: \(jsonObject)")
                    return jsonObject as NSDictionary
                }
            } catch {
                debugPrint("[AuthSessionOutputBridge] JSON encoding error: \(error)")
            }
        }
        
        // Fallback: Use reflection to get properties
        debugPrint("[AuthSessionOutputBridge] Trying reflection fallback")
        let mirror = Mirror(reflecting: object)
        var dict: [String: Any] = [:]
        
        for child in mirror.children {
            if let label = child.label {
                // Map gameUUID to gameUID as per AuthSessionOutput CodingKeys
                let key = label == "gameUUID" ? "gameUID" : label
                dict[key] = child.value
                debugPrint("[AuthSessionOutputBridge] Found property: \(key) = \(child.value)")
            }
        }
        
        if !dict.isEmpty {
            debugPrint("[AuthSessionOutputBridge] Reflection succeeded: \(dict)")
            return dict as NSDictionary
        }
        
        debugPrint("[AuthSessionOutputBridge] Failed to extract dictionary")
        return nil
    }
}

