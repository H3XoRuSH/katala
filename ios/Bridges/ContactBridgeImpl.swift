import Foundation
import Flutter
import Contacts

/**
 * Native iOS ContactBridge implementation using Contacts framework (CNContactStore).
 *
 * Implements 3-tier search relevance strategy:
 * 1. Exact match (case & diacritic insensitive)
 * 2. Prefix match on word components (given/family name)
 * 3. Substring contains match
 * Results are capped at 20 and never cached to disk.
 */
public class ContactBridgeImpl: NSObject {

    public static let channelName = "com.katala.app/contacts"
    private static let maxResults = 20

    private let channel: FlutterMethodChannel
    private let contactStore = CNContactStore()

    public init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: ContactBridgeImpl.channelName, binaryMessenger: messenger)
        super.init()
        self.channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "resolve":
            let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
            let contacts = resolveContacts(query: name)
            result(contacts)
        case "getById":
            if let contactId = (call.arguments as? [String: Any])?["contactId"] as? String {
                let contact = getContactById(contactId: contactId)
                result(contact)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "contactId is required", details: nil))
            }
        case "dispose":
            channel.setMethodCallHandler(nil)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func resolveContacts(query: String) -> [[String: Any]] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            // Per contract: permission denied returns empty list without error
            return []
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var allContacts: [CNContact] = []

        do {
            try contactStore.enumerateContacts(with: request) { (contact, _) in
                allContacts.append(contact)
            }
        } catch {
            return []
        }

        struct ScoredContact {
            let rank: Int
            let contact: CNContact
            let displayName: String
            let primaryPhone: String?
            let allPhones: [String]
        }

        var scored: [ScoredContact] = []

        for contact in allContacts {
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)
                ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)

            guard !fullName.isEmpty else { continue }

            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
            let primaryPhone = phoneNumbers.first

            let rank: Int?
            if fullName.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                rank = 1
            } else if fullName.split(separator: " ").contains(where: { $0.lowercased().hasPrefix(trimmed.lowercased()) }) {
                rank = 2
            } else if fullName.lowercased().contains(trimmed.lowercased()) {
                rank = 3
            } else {
                rank = nil
            }

            if let r = rank {
                scored.append(
                    ScoredContact(
                        rank: r,
                        contact: contact,
                        displayName: fullName,
                        primaryPhone: primaryPhone,
                        allPhones: phoneNumbers
                    )
                )
            }
        }

        let sorted = scored.sorted {
            if $0.rank != $1.rank {
                return $0.rank < $1.rank
            }
            return $0.displayName < $1.displayName
        }

        return sorted.prefix(ContactBridgeImpl.maxResults).map {
            var map: [String: Any] = [
                "platformId": $0.contact.identifier,
                "displayName": $0.displayName,
                "allPhoneNumbers": $0.allPhones
            ]
            if let phone = $0.primaryPhone {
                map["phoneNumber"] = phone
            }
            return map
        }
    }

    private func getContactById(contactId: String) -> [String: Any]? {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            return nil
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        do {
            let contact = try contactStore.unifiedContact(withIdentifier: contactId, keysToFetch: keysToFetch)
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)
                ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
            let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }

            var map: [String: Any] = [
                "platformId": contact.identifier,
                "displayName": fullName,
                "allPhoneNumbers": phoneNumbers
            ]
            if let primary = phoneNumbers.first {
                map["phoneNumber"] = primary
            }
            return map
        } catch {
            return nil
        }
    }
}
