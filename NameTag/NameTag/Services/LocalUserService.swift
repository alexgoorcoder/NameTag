import Foundation
import SwiftData

@Observable
final class LocalUserService {
    private var modelContext: ModelContext
    private(set) var currentProfile: LocalProfile?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadProfile(uid: String) {
        let descriptor = FetchDescriptor<LocalProfile>(predicate: #Predicate { $0.uid == uid })
        currentProfile = try? modelContext.fetch(descriptor).first
    }

    func createProfile(uid: String, firstName: String, lastName: String, photoFileName: String?) throws {
        let profile = LocalProfile(uid: uid, firstName: firstName, lastName: lastName,
                                   photoFileName: photoFileName, createdAt: Date())
        modelContext.insert(profile)
        try modelContext.save()
        currentProfile = profile
    }

    func updateProfile(firstName: String, lastName: String) throws {
        currentProfile?.firstName = firstName
        currentProfile?.lastName = lastName
        currentProfile?.profileVersion += 1
        try modelContext.save()
    }

    func updatePhotoFileName(_ filename: String?) throws {
        currentProfile?.photoFileName = filename
        currentProfile?.profileVersion += 1
        try modelContext.save()
    }

    func deleteProfile() throws {
        if let profile = currentProfile {
            modelContext.delete(profile)
            try modelContext.save()
        }
        currentProfile = nil
    }
}
