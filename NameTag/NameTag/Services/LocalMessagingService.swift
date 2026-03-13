import Foundation
import SwiftData

@Observable
final class LocalMessagingService {
    private var modelContext: ModelContext
    private(set) var conversations: [Conversation] = []
    private(set) var currentMessages: [Message] = []
    private var currentConversationID: String?
    private var currentUID: String

    var unreadCount: Int {
        conversations.filter { $0.isUnread(currentUID: currentUID) }.count
    }

    init(modelContext: ModelContext, currentUID: String) {
        self.modelContext = modelContext
        self.currentUID = currentUID
        loadConversations()
    }

    func loadConversations() {
        let descriptor = FetchDescriptor<LocalConversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let localConvos = (try? modelContext.fetch(descriptor)) ?? []
        conversations = localConvos.map { lc in
            Conversation(id: lc.conversationID, otherUID: lc.otherUID,
                        otherName: lc.otherName, otherPhotoFileName: lc.otherPhotoFileName,
                        lastMessageText: lc.lastMessageText,
                        lastMessageSenderUID: lc.lastMessageSenderUID,
                        lastMessageTimestamp: lc.lastMessageTimestamp,
                        lastReadAt: lc.lastReadAt)
        }
    }

    func loadMessages(conversationID: String) {
        currentConversationID = conversationID
        let descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.conversationID == conversationID },
            sortBy: [SortDescriptor(\.sentAt)]
        )
        let localMsgs = (try? modelContext.fetch(descriptor)) ?? []
        currentMessages = localMsgs.map { lm in
            Message(id: lm.messageID, senderUID: lm.senderUID, text: lm.text,
                    sentAt: lm.sentAt, isDelivered: lm.isDelivered)
        }
    }

    func stopListeningToMessages() {
        currentConversationID = nil
        currentMessages = []
    }

    /// Send a message locally (queued for BLE delivery)
    func sendMessage(text: String, to recipientUID: String, recipientName: String,
                     recipientPhotoFileName: String?) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let conversationID = Conversation.conversationID(uid1: currentUID, uid2: recipientUID)

        // Create or update conversation
        let convDescriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let convo = try? modelContext.fetch(convDescriptor).first {
            convo.lastMessageText = trimmed
            convo.lastMessageSenderUID = currentUID
            convo.lastMessageTimestamp = Date()
        } else {
            let convo = LocalConversation(
                conversationID: conversationID, otherUID: recipientUID,
                otherName: recipientName, otherPhotoFileName: recipientPhotoFileName,
                lastMessageText: trimmed, lastMessageSenderUID: currentUID
            )
            modelContext.insert(convo)
        }

        // Create the message
        let msg = LocalMessage(conversationID: conversationID, senderUID: currentUID, text: trimmed)
        modelContext.insert(msg)
        try modelContext.save()

        loadConversations()
        if currentConversationID == conversationID {
            loadMessages(conversationID: conversationID)
        }
    }

    /// Receive a message from BLE
    func receiveMessage(messageID: String, from senderUID: String, text: String, sentAt: Date,
                        senderName: String, senderPhotoFileName: String?) throws {
        let conversationID = Conversation.conversationID(uid1: currentUID, uid2: senderUID)

        // Duplicate check
        let dupDescriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.messageID == messageID }
        )
        if let existing = try? modelContext.fetch(dupDescriptor), !existing.isEmpty {
            return // Already received
        }

        // Create or update conversation
        let convDescriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let convo = try? modelContext.fetch(convDescriptor).first {
            convo.lastMessageText = text
            convo.lastMessageSenderUID = senderUID
            convo.lastMessageTimestamp = sentAt
            convo.otherName = senderName
            if let photo = senderPhotoFileName {
                convo.otherPhotoFileName = photo
            }
        } else {
            let convo = LocalConversation(
                conversationID: conversationID, otherUID: senderUID,
                otherName: senderName, otherPhotoFileName: senderPhotoFileName,
                lastMessageText: text, lastMessageSenderUID: senderUID,
                lastMessageTimestamp: sentAt
            )
            modelContext.insert(convo)
        }

        // Create the message (already delivered since we received it)
        let msg = LocalMessage(messageID: messageID, conversationID: conversationID,
                               senderUID: senderUID, text: text, sentAt: sentAt, isDelivered: true)
        modelContext.insert(msg)
        try modelContext.save()

        loadConversations()
        if currentConversationID == conversationID {
            loadMessages(conversationID: conversationID)
        }
    }

    /// Get queued (undelivered) messages for a specific contact
    func pendingMessages(for contactUID: String) -> [LocalMessage] {
        let conversationID = Conversation.conversationID(uid1: currentUID, uid2: contactUID)
        let descriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.conversationID == conversationID && $0.isDelivered == false && $0.senderUID == currentUID },
            sortBy: [SortDescriptor(\.sentAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Mark messages as delivered (after BLE confirms receipt)
    func markDelivered(messageIDs: [String]) throws {
        for id in messageIDs {
            let descriptor = FetchDescriptor<LocalMessage>(predicate: #Predicate { $0.messageID == id })
            if let msg = try? modelContext.fetch(descriptor).first {
                msg.isDelivered = true
            }
        }
        try modelContext.save()
        if let currentConversationID {
            loadMessages(conversationID: currentConversationID)
        }
    }

    func markConversationRead(conversationID: String) throws {
        let descriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let convo = try? modelContext.fetch(descriptor).first {
            convo.lastReadAt = Date()
            try modelContext.save()
            loadConversations()
        }
    }

    func deleteConversation(otherUID: String) throws {
        let conversationID = Conversation.conversationID(uid1: currentUID, uid2: otherUID)

        // Delete all messages
        let msgDescriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let messages = try? modelContext.fetch(msgDescriptor) {
            for msg in messages { modelContext.delete(msg) }
        }

        // Delete conversation
        let convDescriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let convo = try? modelContext.fetch(convDescriptor).first {
            modelContext.delete(convo)
        }

        try modelContext.save()
        loadConversations()
    }

    func deleteAllData() throws {
        let msgDescriptor = FetchDescriptor<LocalMessage>()
        if let messages = try? modelContext.fetch(msgDescriptor) {
            for msg in messages { modelContext.delete(msg) }
        }
        let convDescriptor = FetchDescriptor<LocalConversation>()
        if let convos = try? modelContext.fetch(convDescriptor) {
            for convo in convos { modelContext.delete(convo) }
        }
        try modelContext.save()
        conversations = []
        currentMessages = []
    }
}
