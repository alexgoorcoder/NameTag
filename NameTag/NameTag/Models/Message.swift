import Foundation

struct Message: Identifiable, Sendable {
    var id: String
    var senderUID: String
    var text: String
    var sentAt: Date
    var isDelivered: Bool
}
