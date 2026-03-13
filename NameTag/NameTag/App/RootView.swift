import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState: AppState?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let appState {
                if appState.hasCompletedOnboarding {
                    MainTabView()
                        .environment(appState)
                } else {
                    OnboardingView()
                        .environment(appState)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            let state = AppState(modelContext: modelContext)
            state.onAppReady()
            appState = state
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                appState?.notificationGatekeeper.isOnNearbyTab = false
                appState?.recheckNearbyNotifications()
            case .active:
                appState?.notificationGatekeeper.cancelPendingNotifications()
                appState?.resumeForegroundServices()
            default:
                break
            }
        }
    }
}
