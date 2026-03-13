import SwiftUI

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    let conversationID: String
    let otherUserUID: String
    let otherUserName: String
    let otherUserPhotoFileName: String?

    @State private var messageText = ""
    @State private var isSending = false

    // Init from Connection (contact detail entry)
    init(connection: Connection, currentUID: String) {
        self.conversationID = Conversation.conversationID(uid1: currentUID, uid2: connection.userId)
        self.otherUserUID = connection.userId
        self.otherUserName = connection.fullName
        self.otherUserPhotoFileName = connection.photoFileName
    }

    // Init from Conversation (inbox entry)
    init(conversation: Conversation, currentUID: String) {
        self.conversationID = conversation.id
        self.otherUserUID = conversation.otherUID
        self.otherUserName = conversation.otherName
        self.otherUserPhotoFileName = conversation.otherPhotoFileName
    }

    private var currentUID: String {
        appState.identityService.currentUID
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.localMessagingService.currentMessages) { message in
                            messageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .onChange(of: appState.localMessagingService.currentMessages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                    // Mark as read when new messages arrive while viewing
                    try? appState.localMessagingService.markConversationRead(
                        conversationID: conversationID
                    )
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // Message input bar
            messageInputBar
        }
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appState.localMessagingService.loadMessages(conversationID: conversationID)
            try? appState.localMessagingService.markConversationRead(
                conversationID: conversationID
            )
        }
        .onDisappear {
            appState.localMessagingService.stopListeningToMessages()
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(message: Message) -> some View {
        let isSent = message.senderUID == currentUID

        HStack {
            if isSent { Spacer(minLength: 60) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isSent ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(isSent ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 4) {
                    Text(message.sentAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    // Delivery status for sent messages
                    if isSent && !message.isDelivered {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isSent { Spacer(minLength: 60) }
        }
    }

    // MARK: - Message Input Bar

    private var messageInputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Send Message

    private func sendMessage() {
        let text = messageText
        messageText = ""
        isSending = true

        do {
            try appState.localMessagingService.sendMessage(
                text: text,
                to: otherUserUID,
                recipientName: otherUserName,
                recipientPhotoFileName: otherUserPhotoFileName
            )
        } catch {
            // Restore the message text on failure so user can retry
            messageText = text
            print("[ConversationView] sendMessage failed: \(error.localizedDescription)")
        }

        isSending = false
    }

    // MARK: - Scroll

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = appState.localMessagingService.currentMessages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
