import SwiftUI

struct BLEAddContactView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var howDoIKnow = ""
    @State private var isScanning = false
    @State private var discoveredPeers: [DiscoveredPeer] = []
    @State private var selectedPeer: DiscoveredPeer?
    @State private var addedSuccessfully = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if addedSuccessfully {
                    successView
                } else if let peer = selectedPeer {
                    confirmView(peer: peer)
                } else {
                    scanningView
                }
            }
            .padding()
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { startScanning() }
            .onDisappear { stopScanning() }
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text("Looking for nearby contacts...")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Ask the other person to also tap\n\"Add Contact\" on their device.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if !discoveredPeers.isEmpty {
                VStack(spacing: 8) {
                    Text("Nearby")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(discoveredPeers) { peer in
                        Button {
                            selectedPeer = peer
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                Text(peer.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Confirm View

    private func confirmView(peer: DiscoveredPeer) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("Add \(peer.name)?")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("How do I know this person?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g. Met at conference, coworker...", text: $howDoIKnow)
                    .padding()
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                addContact(peer: peer)
            } label: {
                Text("Add Contact")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Back") {
                selectedPeer = nil
                howDoIKnow = ""
                errorMessage = nil
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Contact Added!")
                .font(.title2.bold())

            if let peer = selectedPeer {
                Text("\(peer.name) has been added to your contacts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Actions

    private func startScanning() {
        isScanning = true
        // BLEDataService will handle handshake scanning when implemented
        // For now, peers will be populated by the BLE handshake discovery
    }

    private func stopScanning() {
        isScanning = false
    }

    private func addContact(peer: DiscoveredPeer) {
        errorMessage = nil
        do {
            try appState.localContactsService.addContact(
                uid: peer.uid,
                firstName: peer.firstName,
                lastName: peer.lastName,
                photoFileName: peer.photoFileName,
                howDoIKnow: howDoIKnow.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            addedSuccessfully = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Represents a peer discovered during BLE handshake
struct DiscoveredPeer: Identifiable {
    let id: String  // Same as uid
    let uid: String
    let firstName: String
    let lastName: String
    let photoFileName: String?

    var name: String { "\(firstName) \(lastName)" }
}
