import Foundation
import Security

struct KeychainItem {
    // MARK: Types
    
    enum KeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unexpectedItemData
        case unhandledError
    }
    
    // MARK: Properties
    private static let serviceName = "com.illinispots.app"
    private static let accountName = "userIdentifier"
    
    let service: String
    let account: String
    private let accessGroup: String?
    
    // MARK: Intialization
    
    private init(service: String, account: String, accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }
    
    // MARK: Static Methods
    
    static func createItem(service: String = KeychainItem.serviceName, account: String, accessGroup: String? = nil) -> KeychainItem {
        return KeychainItem(service: service, account: account, accessGroup: accessGroup)
    }
    
    // MARK: Keychain access
    
    static var currentUserIdentifier: String? {
        get {
            do {
                let item = KeychainItem(service: KeychainItem.serviceName, account: KeychainItem.accountName)
                let storedIdentifier = try item.readItem()
                return storedIdentifier
            } catch {
                return nil
            }
        }
    }
    
    static func deleteUserIdentifierFromKeychain() {
        do {
            let item = KeychainItem(service: KeychainItem.serviceName, account: KeychainItem.accountName)
            try item.deleteItem()
        } catch {
            print("Unable to delete userIdentifier from keychain")
        }
    }
    
    static func saveUserIdentifier(_ identifier: String) throws {
        let item = KeychainItem(service: KeychainItem.serviceName, account: KeychainItem.accountName)
        try item.saveItem(identifier)
    }
    
    // MARK: Instance Methods
    
    func saveItem(_ password: String) throws {
        // Encode the password into data
        let encodedPassword = password.data(using: String.Encoding.utf8)!
        
        do {
            // Check for an existing item in the keychain
            try _ = readItem()
            
            // Update the existing item with the new password
            var attributesToUpdate = [String: AnyObject]()
            attributesToUpdate[kSecValueData as String] = encodedPassword as AnyObject
            
            let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            // Throw an error if an unexpected status was returned
            guard status == noErr else { throw KeychainError.unhandledError }
        } catch KeychainError.noPassword {
            // No password was found in the keychain. Create a dictionary to save as a new keychain item.
            var newItem = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
            newItem[kSecValueData as String] = encodedPassword as AnyObject
            
            // Add a the new item to the keychain
            let status = SecItemAdd(newItem as CFDictionary, nil)
            
            // Throw an error if an unexpected status was returned
            guard status == noErr else { throw KeychainError.unhandledError }
        }
    }
    
    private func readItem() throws -> String {
        // Build a query to find the item that matches the service, account and access group
        var query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecReturnData as String] = kCFBooleanTrue
        
        // Try to fetch the existing keychain item that matches the query
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }
        
        // Check the return status and throw an error if appropriate
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == noErr else { throw KeychainError.unhandledError }
        
        // Parse the password string from the query result
        guard let existingItem = queryResult as? [String: AnyObject],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
        else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return password
    }
    
    private func deleteItem() throws {
        // Delete the existing item from the keychain
        let query = KeychainItem.keychainQuery(withService: service, account: account, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        
        // Throw an error if an unexpected status was returned
        guard status == noErr || status == errSecItemNotFound else { throw KeychainError.unhandledError }
    }
    
    // MARK: Convenience
    
    private static func keychainQuery(withService service: String, account: String? = nil, accessGroup: String? = nil) -> [String: AnyObject] {
        var query = [String: AnyObject]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service as AnyObject
        
        if let account = account {
            query[kSecAttrAccount as String] = account as AnyObject
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup as AnyObject
        }
        
        return query
    }
} 