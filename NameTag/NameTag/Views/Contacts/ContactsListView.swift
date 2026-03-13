import SwiftUI

struct ContactsListView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddContact = false
    @State private var selectedConnection: Connection?

    var body: some View {
        NavigationStack {
            Group {
                if appState.localContactsService.connections.isEmpty {
                    ContentUnavailableView(
                        "No Contacts Yet",
                        systemImage: "person.slash",
                        description: Text("Tap + to add contacts when they're nearby via Bluetooth.")
                    )
                } else {
                    List {
                        ForEach(appState.localContactsService.connections) { connection in
                            connectionRow(connection: connection)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let connection = appState.localContactsService.connections[index]
                                try? appState.localContactsService.removeContact(uid: connection.userId)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                BLEAddContactView()
            }
            .sheet(item: $selectedConnection) { connection in
                ContactDetailSheet(connection: connection)
            }
        }
    }

    // MARK: - Connection Row

    private func connectionRow(connection: Connection) -> some View {
        Button {
            selectedConnection = connection
        } label: {
            HStack(spacing: 12) {
                AsyncProfileImage(photoFileName: connection.photoFileName)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .opacity(connection.proximityPaused ? 0.5 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(connection.fullName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if connection.proximityPaused {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    if !connection.howDoIKnow.isEmpty {
                        Text(connection.howDoIKnow)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
