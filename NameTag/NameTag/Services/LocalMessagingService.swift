import Foundation
import SwiftData
import CryptoKit

@Observable
final class LocalMessagingService {
    private var modelContext: ModelContext
    private(set) var conversations: [Conversation] = []
    private(set) var currentMessages: [Message] = []
    private var currentConversationID: String?
    private var currentUID: String
    private var deviceKey: SymmetricKey?

    var unreadCount: Int {
        conversations.filter { $0.isUnread(currentUID: currentUID) }.count
    }

    init(modelContext: ModelContext, currentUID: String) {
        self.modelContext = modelContext
        self.currentUID = currentUID
        loadConversations()
    }

    /// Set the device encryption key for encrypting message text at rest
    func configureEncryption(deviceKey: SymmetricKey) {
        self.deviceKey = deviceKey
        // Reload to decrypt existing messages
        loadConversations()
        if let currentConversationID {
            loadMessages(conversationID: currentConversationID)
        }
    }

    func loadConversations() {
        let descriptor = FetchDescriptor<LocalConversation>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let localConvos = (try? modelContext.fetch(descriptor)) ?? []
        conversations = localConvos.map { lc in
            Conversation(id: lc.conversationID, otherUID: lc.otherUID,
                        otherName: lc.otherName, otherPhotoFileName: lc.otherPhotoFileName,
                        lastMessageText: decryptText(lc.lastMessageText),
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
            Message(id: lm.messageID, senderUID: lm.senderUID, text: decryptText(lm.text),
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

        let encryptedText = encryptText(trimmed)
        let conversationID = Conversation.conversationID(uid1: currentUID, uid2: recipientUID)

        // Create or update conversation
        let convDescriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let convo = try? modelContext.fetch(convDescriptor).first {
            convo.lastMessageText = encryptedText
            convo.lastMessageSenderUID = currentUID
            convo.lastMessageTimestamp = Date()
        } else {
            let convo = LocalConversation(
                conversationID: conversationID, otherUID: recipientUID,
                otherName: recipientName, otherPhotoFileName: recipientPhotoFileName,
                lastMessageText: encryptedText, lastMessageSenderUID: currentUID
            )
            modelContext.insert(convo)
        }

        // Create the message
        let msg = LocalMessage(conversationID: conversationID, senderUID: currentUID, text: encryptedText)
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

        let encryptedText = encryptText(text)

        // Create or update conversation
        let convDescriptor = FetchDescriptor<LocalConversation>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let convo = try? modelContext.fetch(convDescriptor).first {
            convo.lastMessageText = encryptedText
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
                lastMessageText: encryptedText, lastMessageSenderUID: senderUID,
                lastMessageTimestamp: sentAt
            )
            modelContext.insert(convo)
        }

        // Create the message (already delivered since we received it)
        let msg = LocalMessage(messageID: messageID, conversationID: conversationID,
                               senderUID: senderUID, text: encryptedText, sentAt: sentAt, isDelivered: true)
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

    /// Get the plaintext of a pending message for BLE transmission
    func plaintextForPendingMessage(_ message: LocalMessage) -> String {
        decryptText(message.text)
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

        let msgDescriptor = FetchDescriptor<LocalMessage>(
            predicate: #Predicate { $0.conversationID == conversationID }
        )
        if let messages = try? modelContext.fetch(msgDescriptor) {
            for msg in messages { modelContext.delete(msg) }
        }

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

    // MARK: - Encryption Helpers

    /// Encrypt text for storage. Returns base64-encoded ciphertext, or plaintext if no key set.
    private func encryptText(_ plaintext: String) -> String {
        guard let key = deviceKey else { return plaintext }
        guard let data = plaintext.data(using: .utf8),
              let encrypted = try? CryptoService.encrypt(data: data, key: key) else {
            return plaintext
        }
        return "enc:" + encrypted.base64EncodedString()
    }

    /// Decrypt stored text. Handles both encrypted ("enc:...") and legacy plaintext.
    private func decryptText(_ stored: String) -> String {
        guard stored.hasPrefix("enc:"), let key = deviceKey else { return stored }
        let base64 = String(stored.dropFirst(4))
        guard let data = Data(base64Encoded: base64),
              let decrypted = try? CryptoService.decrypt(data: data, key: key),
              let text = String(data: decrypted, encoding: .utf8) else {
            return "[encrypted]"
        }
        return text
    }
}
