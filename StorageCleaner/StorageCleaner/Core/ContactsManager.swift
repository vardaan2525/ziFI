import Foundation
import Contacts
import SwiftUI

// MARK: - Contact Item Model
public struct ContactItem: Identifiable, Hashable {
    public let id: String
    public let givenName: String
    public let familyName: String
    public let fullName: String
    public let phoneNumbers: [String]
    public let emailAddresses: [String]
    public let organizationName: String
    
    public init(contact: CNContact) {
        self.id = contact.identifier
        self.givenName = contact.givenName
        self.familyName = contact.familyName
        
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            self.fullName = name
        } else if !contact.organizationName.isEmpty {
            self.fullName = contact.organizationName
        } else if let firstPhone = contact.phoneNumbers.first?.value.stringValue {
            self.fullName = firstPhone
        } else {
            self.fullName = "Unnamed Contact"
        }
        
        self.phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        self.emailAddresses = contact.emailAddresses.map { String($0.value) }
        self.organizationName = contact.organizationName
    }
    
    public var normalizedPhoneNumbers: [String] {
        phoneNumbers.map { Self.normalizePhone($0) }.filter { !$0.isEmpty }
    }
    
    public static func normalizePhone(_ phone: String) -> String {
        phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}

// MARK: - Duplicate Contact Group
public struct DuplicateContactGroup: Identifiable, Hashable {
    public enum DuplicateReason: String, CaseIterable {
        case sameName = "Identical Name"
        case samePhone = "Same Phone Number"
        case sameEmail = "Same Email Address"
    }
    
    public let id: String
    public let title: String
    public let reason: DuplicateReason
    public var contacts: [ContactItem]
    
    public init(id: String = UUID().uuidString, title: String, reason: DuplicateReason, contacts: [ContactItem]) {
        self.id = id
        self.title = title
        self.reason = reason
        self.contacts = contacts
    }
}

// MARK: - Contacts Manager
@MainActor
public class ContactsManager: ObservableObject {
    public static let shared = ContactsManager()
    
    private let contactStore = CNContactStore()
    
    @Published public var authStatus: CNAuthorizationStatus = .notDetermined
    @Published public var isLoading: Bool = false
    @Published public var allContacts: [ContactItem] = []
    @Published public var duplicateNameGroups: [DuplicateContactGroup] = []
    @Published public var duplicatePhoneGroups: [DuplicateContactGroup] = []
    @Published public var missingInfoContacts: [ContactItem] = []
    @Published public var statusMessage: String?
    
    public var totalDuplicatesCount: Int {
        let nameDuplicates = duplicateNameGroups.reduce(0) { $0 + max(0, $1.contacts.count - 1) }
        let phoneDuplicates = duplicatePhoneGroups.reduce(0) { $0 + max(0, $1.contacts.count - 1) }
        return nameDuplicates + phoneDuplicates
    }
    
    private init() {
        checkPermission()
    }
    
    public func checkPermission() {
        self.authStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    public func requestAccess() async -> Bool {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            self.authStatus = CNContactStore.authorizationStatus(for: .contacts)
            if granted {
                await scanContacts()
            }
            return granted
        } catch {
            self.authStatus = CNContactStore.authorizationStatus(for: .contacts)
            return false
        }
    }
    
    public func scanContacts() async {
        guard authStatus == .authorized else {
            checkPermission()
            guard authStatus == .authorized else { return }
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor
        ]
        
        let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        var fetchedContacts: [ContactItem] = []
        do {
            try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                fetchedContacts.append(ContactItem(contact: contact))
            }
        } catch {
            print("Failed to enumerate contacts: \(error)")
            return
        }
        
        self.allContacts = fetchedContacts
        
        // 1. Group by identical name
        var nameMap: [String: [ContactItem]] = [:]
        for item in fetchedContacts {
            let cleanedName = item.fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if cleanedName != "unnamed contact" && !cleanedName.isEmpty {
                nameMap[cleanedName, default: []].append(item)
            }
        }
        self.duplicateNameGroups = nameMap
            .filter { $0.value.count > 1 }
            .map { key, items in
                DuplicateContactGroup(
                    title: items.first?.fullName ?? key.capitalized,
                    reason: .sameName,
                    contacts: items
                )
            }
            .sorted { $0.title < $1.title }
        
        // 2. Group by identical normalized phone numbers
        var phoneMap: [String: [ContactItem]] = [:]
        for item in fetchedContacts {
            for phone in item.normalizedPhoneNumbers where phone.count >= 7 {
                phoneMap[phone, default: []].append(item)
            }
        }
        
        // Filter phone groups that are not already exact same name duplicates
        let existingNameDuplicateIds = Set(duplicateNameGroups.flatMap { $0.contacts.map { $0.id } })
        
        self.duplicatePhoneGroups = phoneMap
            .filter { $0.value.count > 1 }
            .compactMap { phone, items -> DuplicateContactGroup? in
                // Deduplicate items in case one contact had multiple identical numbers
                let uniqueItems = Array(Dictionary(grouping: items, by: { $0.id }).compactMap { $0.value.first })
                guard uniqueItems.count > 1 else { return nil }
                // Check if already captured by name duplicates
                let ids = uniqueItems.map { $0.id }
                if ids.allSatisfy({ existingNameDuplicateIds.contains($0) }) {
                    return nil
                }
                return DuplicateContactGroup(
                    title: items.first?.fullName ?? phone,
                    reason: .samePhone,
                    contacts: uniqueItems
                )
            }
            .sorted { $0.title < $1.title }
        
        // 3. Missing info contacts (no phone and no email)
        self.missingInfoContacts = fetchedContacts.filter { item in
            item.phoneNumbers.isEmpty && item.emailAddresses.isEmpty
        }
    }
    
    // MARK: - Merge Duplicate Group
    public func mergeGroup(_ group: DuplicateContactGroup) async -> Bool {
        guard let primary = group.contacts.first else { return false }
        let duplicateIds = group.contacts.dropFirst().map { $0.id }
        
        do {
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactPostalAddressesKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            
            guard let primaryCN = try? contactStore.unifiedContact(withIdentifier: primary.id, keysToFetch: keysToFetch) else {
                return false
            }
            
            let mutablePrimary = primaryCN.mutableCopy() as! CNMutableContact
            let saveRequest = CNSaveRequest()
            
            // Gather existing phone strings to prevent duplicates in primary
            var existingPhones = Set(primaryCN.phoneNumbers.map { ContactItem.normalizePhone($0.value.stringValue) })
            var existingEmails = Set(primaryCN.emailAddresses.map { String($0.value).lowercased() })
            
            for extraId in duplicateIds {
                if let extraCN = try? contactStore.unifiedContact(withIdentifier: extraId, keysToFetch: keysToFetch) {
                    // Copy unique phone numbers
                    for labeledPhone in extraCN.phoneNumbers {
                        let normalized = ContactItem.normalizePhone(labeledPhone.value.stringValue)
                        if !existingPhones.contains(normalized) && !normalized.isEmpty {
                            existingPhones.insert(normalized)
                            mutablePrimary.phoneNumbers.append(labeledPhone)
                        }
                    }
                    // Copy unique email addresses
                    for labeledEmail in extraCN.emailAddresses {
                        let emailStr = String(labeledEmail.value).lowercased()
                        if !existingEmails.contains(emailStr) && !emailStr.isEmpty {
                            existingEmails.insert(emailStr)
                            mutablePrimary.emailAddresses.append(labeledEmail)
                        }
                    }
                    // Delete the duplicate
                    let mutableExtra = extraCN.mutableCopy() as! CNMutableContact
                    saveRequest.delete(mutableExtra)
                }
            }
            
            saveRequest.update(mutablePrimary)
            try contactStore.execute(saveRequest)
            
            HapticManager.notification(type: .success)
            await scanContacts()
            return true
        } catch {
            print("Failed to merge contact group: \(error)")
            HapticManager.notification(type: .error)
            return false
        }
    }
    
    // MARK: - Merge All Duplicates
    public func mergeAllDuplicates() async -> Int {
        var mergedCount = 0
        let allGroups = duplicateNameGroups + duplicatePhoneGroups
        for group in allGroups {
            let success = await mergeGroup(group)
            if success {
                mergedCount += 1
            }
        }
        return mergedCount
    }
    
    // MARK: - Delete Contacts
    public func deleteContacts(ids: [String]) async -> Bool {
        do {
            let keysToFetch: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor]
            let saveRequest = CNSaveRequest()
            
            for id in ids {
                if let contact = try? contactStore.unifiedContact(withIdentifier: id, keysToFetch: keysToFetch) {
                    let mutable = contact.mutableCopy() as! CNMutableContact
                    saveRequest.delete(mutable)
                }
            }
            
            try contactStore.execute(saveRequest)
            HapticManager.notification(type: .success)
            await scanContacts()
            return true
        } catch {
            print("Failed to delete contacts: \(error)")
            HapticManager.notification(type: .error)
            return false
        }
    }
}
