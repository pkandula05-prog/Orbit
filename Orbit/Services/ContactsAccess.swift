import Contacts
import Foundation

/// Reads phone numbers from the address book, and only ever if the person says yes.
///
/// Nothing is read — and no permission is asked for — until `requestAndFetch()` is called from
/// the friends page. A real backend should be handed salted hashes rather than these numbers.
enum ContactsAccess {
    static var status: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    static var isDenied: Bool { status == .denied || status == .restricted }

    /// Returns the phone numbers to match against, or nil if access was refused.
    static func requestAndFetch() async -> [String]? {
        let store = CNContactStore()
        guard (try? await store.requestAccess(for: .contacts)) == true else { return nil }

        return await Task.detached(priority: .userInitiated) {
            let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var numbers: [String] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                numbers.append(contentsOf: contact.phoneNumbers.map(\.value.stringValue))
            }
            return numbers
        }.value
    }
}
