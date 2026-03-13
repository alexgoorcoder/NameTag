import Foundation

struct Conversation: Identifiable, Sendable, Hashable {
    var id: String
    var otherUID: String
    var otherName: String
    var otherPhotoFileName: String?
    var lastMessageText: String
    var lastMessageSenderUID: String
    var lastMessageTimestamp: Date
    var lastReadAt: Date?

    /// Returns the deterministic conversation ID for two UIDs
    static func conversationID(uid1: String, uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }

    /// Whether this conversation has unread messages for the given user
    func isUnread(currentUID: String) -> Bool {
        guard lastMessageSenderUID != currentUID else { return false }
        guard let lastRead = lastReadAt else { return true }
        return lastMessageTimestamp > lastRead
    }
}
