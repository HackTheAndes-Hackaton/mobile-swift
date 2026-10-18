import Foundation
@preconcurrency import Contacts

struct PhoneContact: Identifiable, Sendable {
    struct Phone: Identifiable, Sendable { let id: String; let label: String; let number: String }
    let id: String
    let name: String
    let phones: [Phone]
    var initial: String { name.first.map { String($0).uppercased() } ?? "#" }
}
@MainActor final class ContactsBook: ObservableObject {
    @Published private(set) var contacts: [PhoneContact] = []
    @Published private(set) var allowed = false
    @Published private(set) var loading = false
    @Published var message = ""
    func refresh(requestPermission: Bool = false) async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do {
            if requestPermission { _ = try await CNContactStore().requestAccess(for:.contacts) }
            let status = CNContactStore.authorizationStatus(for:.contacts)
            if #available(iOS 18.0, *) { allowed = status == .authorized || status == .limited }
            else { allowed = status == .authorized }
            guard allowed else { contacts = []; return }
            contacts = try await Task.detached(priority:.userInitiated) {
                let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor,CNContactGivenNameKey as CNKeyDescriptor,CNContactFamilyNameKey as CNKeyDescriptor,CNContactOrganizationNameKey as CNKeyDescriptor,CNContactPhoneNumbersKey as CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch:keys); request.sortOrder = .givenName
                var entries: [PhoneContact] = []
                try CNContactStore().enumerateContacts(with:request) { contact, stop in
                    guard !contact.phoneNumbers.isEmpty else { return }
                    let name = [contact.givenName,contact.familyName].filter { !$0.isEmpty }.joined(separator:" ")
                    let phones = contact.phoneNumbers.map { PhoneContact.Phone(id:$0.identifier,label:CNLabeledValue<NSString>.localizedString(forLabel:$0.label ?? "teléfono"),number:$0.value.stringValue) }
                    entries.append(PhoneContact(id:contact.identifier,name:name.isEmpty ? (contact.organizationName.isEmpty ? phones[0].number : contact.organizationName) : name,phones:phones))
                    if entries.count >= 10_000 { stop.pointee = true }
                }
                return entries
            }.value
            message = ""
        } catch { message = "No se pudieron cargar los contactos. Revisa el permiso en Ajustes de iOS." }
    }
}
