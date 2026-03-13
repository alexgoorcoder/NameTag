import Foundation

@Observable
final class CardStackViewModel {
    private(set) var nearbyContacts: [NearbyContact] = []
    private var refreshTimer: Timer?

    func startMonitoring(appState: AppState) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshNearbyContacts(appState: appState)
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshNearbyContacts(appState: AppState) {
        let connectionUIDs = appState.localContactsService.connectionUIDs

        // Update BLE service with latest connection UIDs
        appState.bleService.updateConnectionUIDs(connectionUIDs)

        // BLE is the only proximity source
        let nearby = appState.bleService.nearbyUserIDs
            .filter { connectionUIDs.contains($0.key) }

        let connections = appState.localContactsService.connections.filter { !$0.proximityPaused }

        // Build NearbyContact for each detected connection
        var result: [NearbyContact] = []
        for connection in connections {
            if let info = nearby[connection.userId] {
                result.append(NearbyContact(
                    id: connection.userId,
                    connection: connection,
                    lastSeenAt: info.lastSeen,
                    rssi: info.rssi
                ))
            }
        }

        // Sort by lastSeenAt descending (most recent on top)
        result.sort { $0.lastSeenAt > $1.lastSeenAt }
        nearbyContacts = result
    }
}
