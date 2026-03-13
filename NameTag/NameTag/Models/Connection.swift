import Foundation

struct Connection: Identifiable, Sendable, Hashable {
    var id: String
    var userId: String
    var firstName: String
    var lastName: String
    var photoFileName: String?
    var howDoIKnow: String
    var connectedAt: Date
    var isPaused: Bool?

    var fullName: String { "\(firstName) \(lastName)" }

    /// Whether proximity detection is paused for this contact
    var proximityPaused: Bool { isPaused ?? false }
}
