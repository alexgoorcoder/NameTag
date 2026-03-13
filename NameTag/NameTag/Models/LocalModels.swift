import Foundation
import SwiftData

@Model
final class LocalProfile {
    @Attribute(.unique) var uid: String
    var firstName: String
    var lastName: String
    var photoFileName: String?
    var profileVersion: Int
    var createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }

    init(uid: String, firstName: String, lastName: String, photoFileName: String? = nil, createdAt: Date = Date()) {
        self.uid = uid
        self.firstName = firstName
        self.lastName = lastName
        self.photoFileName = photoFileName
        self.profileVersion = 1
        self.createdAt = createdAt
    }
}

@Model
final class LocalContact {
    @Attribute(.unique) var contactUID: String
    var firstName: String
    var lastName: String
    var photoFileName: String?
    var howDoIKnow: String
    var connectedAt: Date
    var isPaused: Bool
    var lastSyncedProfileVersion: Int

    var fullName: String { "\(firstName) \(lastName)" }
    var proximityPaused: Bool { isPaused }

    init(contactUID: String, firstName: String, lastName: String, photoFileName: String? = nil,
         howDoIKnow: String = "", connectedAt: Date = Date(), isPaused: Bool = false) {
        self.contactUID = contactUID
        self.firstName = firstName
        self.lastName = lastName
        self.photoFileName = photoFileName
        self.howDoIKnow = howDoIKnow
        self.connectedAt = connectedAt
        self.isPaused = isPaused
        self.lastSyncedProfileVersion = 0
    }
}

@Model
final class LocalConversation {
    @Attribute(.unique) var conversationID: String
    var otherUID: String
    var otherName: String
    var otherPhotoFileName: String?
    var lastMessageText: String
    var lastMessageSenderUID: String
    var lastMessageTimestamp: Date
    var lastReadAt: Date?

    init(conversationID: String, otherUID: String, otherName: String, otherPhotoFileName: String? = nil,
         lastMessageText: String, lastMessageSenderUID: String, lastMessageTimestamp: Date = Date()) {
        self.conversationID = conversationID
        self.otherUID = otherUID
        self.otherName = otherName
        self.otherPhotoFileName = otherPhotoFileName
        self.lastMessageText = lastMessageText
        self.lastMessageSenderUID = lastMessageSenderUID
        self.lastMessageTimestamp = lastMessageTimestamp
    }
}

@Model
final class LocalMessage {
    @Attribute(.unique) var messageID: String
    var conversationID: String
    var senderUID: String
    var text: String
    var sentAt: Date
    var isDelivered: Bool

    init(conversationID: String, senderUID: String, text: String, sentAt: Date = Date(), isDelivered: Bool = false) {
        self.messageID = UUID().uuidString
        self.conversationID = conversationID
        self.senderUID = senderUID
        self.text = text
        self.sentAt = sentAt
        self.isDelivered = isDelivered
    }

    init(messageID: String, conversationID: String, senderUID: String, text: String, sentAt: Date, isDelivered: Bool) {
        self.messageID = messageID
        self.conversationID = conversationID
        self.senderUID = senderUID
        self.text = text
        self.sentAt = sentAt
        self.isDelivered = isDelivered
    }
}
