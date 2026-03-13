import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: String = "nearby"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Nearby", systemImage: "person.2.wave.2", value: "nearby") {
                CardStackView()
            }

            Tab("Contacts", systemImage: "person.crop.rectangle.stack", value: "contacts") {
                ContactsListView()
            }

            Tab("Messages", systemImage: "bubble.left.and.bubble.right", value: "messages") {
                MessagesListView()
            }
            .badge(appState.localMessagingService.unreadCount)

            Tab("Profile", systemImage: "person.circle", value: "profile") {
                ProfileView()
            }
        }
        .onChange(of: selectedTab, initial: true) { _, newTab in
            appState.notificationGatekeeper.isOnNearbyTab = (newTab == "nearby")
        }
        .onChange(of: appState.localContactsService.connectionUIDs, initial: true) { _, newUIDs in
            appState.bleService.updateConnectionUIDs(newUIDs)
        }
        .onChange(of: appState.localContactsService.connections, initial: true) { _, connections in
            let names = Dictionary(
                uniqueKeysWithValues: connections.map { ($0.userId, $0.fullName) }
            )
            appState.notificationGatekeeper.connectionNames = names
        }
    }
}
