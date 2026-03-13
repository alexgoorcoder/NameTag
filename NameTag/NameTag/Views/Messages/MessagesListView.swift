import SwiftUI

struct MessagesListView: View {
    @Environment(AppState.self) private var appState

    private var currentUID: String {
        appState.identityService.currentUID
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.localMessagingService.conversations.isEmpty {
                    ContentUnavailableView(
                        "No Messages Yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Messages with your contacts will appear here.")
                    )
                } else {
                    List {
                        ForEach(appState.localMessagingService.conversations) { conversation in
                            NavigationLink(value: conversation) {
                                conversationRow(conversation: conversation)
                            }
                        }
                    }
                    .navigationDestination(for: Conversation.self) { conversation in
                        ConversationView(conversation: conversation, currentUID: currentUID)
                    }
                }
            }
            .navigationTitle("Messages")
        }
    }

    // MARK: - Conversation Row

    private func conversationRow(conversation: Conversation) -> some View {
        let unread = conversation.isUnread(currentUID: currentUID)

        return HStack(spacing: 12) {
            // Unread dot
            Circle()
                .fill(unread ? Color.blue : Color.clear)
                .frame(width: 10, height: 10)

            AsyncProfileImage(photoFileName: conversation.otherPhotoFileName)
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.otherName)
                    .font(.body.weight(unread ? .bold : .semibold))
                    .lineLimit(1)

                Text(conversation.lastMessageText)
                    .font(.subheadline)
                    .foregroundStyle(unread ? .primary : .secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(conversation.lastMessageTimestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
