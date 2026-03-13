import Foundation

@Observable
final class ConnectionsViewModel {
    var errorMessage: String?

    func removeConnection(uid: String, using appState: AppState) {
        do {
            try appState.localMessagingService.deleteConversation(otherUID: uid)
            try appState.localContactsService.removeContact(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
