import Foundation
import SwiftData

@Observable
final class LocalContactsService {
    private var modelContext: ModelContext
    private(set) var contacts: [LocalContact] = []

    var connectionUIDs: Set<String> {
        Set(contacts.filter { !$0.isPaused }.map(\.contactUID))
    }

    var allConnectionUIDs: Set<String> {
        Set(contacts.map(\.contactUID))
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadContacts()
    }

    func loadContacts() {
        let descriptor = FetchDescriptor<LocalContact>(sortBy: [SortDescriptor(\.connectedAt, order: .reverse)])
        contacts = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addContact(uid: String, firstName: String, lastName: String, photoFileName: String?, howDoIKnow: String) throws {
        // Check if already exists
        guard !allConnectionUIDs.contains(uid) else { return }
        let contact = LocalContact(contactUID: uid, firstName: firstName, lastName: lastName,
                                   photoFileName: photoFileName, howDoIKnow: howDoIKnow,
                                   connectedAt: Date(), isPaused: false)
        modelContext.insert(contact)
        try modelContext.save()
        loadContacts()
    }

    func removeContact(uid: String) throws {
        if let contact = contacts.first(where: { $0.contactUID == uid }) {
            modelContext.delete(contact)
            try modelContext.save()
            loadContacts()
        }
    }

    func togglePause(uid: String) throws {
        if let contact = contacts.first(where: { $0.contactUID == uid }) {
            contact.isPaused.toggle()
            try modelContext.save()
            loadContacts()
        }
    }

    func updateHowDoIKnow(uid: String, howDoIKnow: String) throws {
        if let contact = contacts.first(where: { $0.contactUID == uid }) {
            contact.howDoIKnow = howDoIKnow
            try modelContext.save()
        }
    }

    func updateContactProfile(uid: String, firstName: String, lastName: String, photoFileName: String?) throws {
        if let contact = contacts.first(where: { $0.contactUID == uid }) {
            contact.firstName = firstName
            contact.lastName = lastName
            contact.photoFileName = photoFileName
            try modelContext.save()
            loadContacts()
        }
    }

    func updateLastSyncedVersion(uid: String, version: Int) throws {
        if let contact = contacts.first(where: { $0.contactUID == uid }) {
            contact.lastSyncedProfileVersion = version
            try modelContext.save()
        }
    }

    func deleteAllContacts() throws {
        for contact in contacts {
            modelContext.delete(contact)
        }
        try modelContext.save()
        contacts = []
    }

    /// Build Connection structs for the view layer
    var connections: [Connection] {
        contacts.map { c in
            Connection(id: c.contactUID, userId: c.contactUID, firstName: c.firstName,
                      lastName: c.lastName, photoFileName: c.photoFileName,
                      howDoIKnow: c.howDoIKnow, connectedAt: c.connectedAt, isPaused: c.isPaused)
        }
    }
}
