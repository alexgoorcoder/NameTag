import Foundation

/// Lightweight transfer struct used during BLE profile exchange
struct AppUser: Codable, Identifiable, Sendable, Hashable {
    var id: String
    var firstName: String
    var lastName: String
    var photoData: Data?
    var createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }

    init(
        id: String,
        firstName: String,
        lastName: String,
        photoData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.photoData = photoData
        self.createdAt = createdAt
    }
}
