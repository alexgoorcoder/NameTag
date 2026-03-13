import SwiftUI
import SwiftData
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set ourselves as the notification delegate so notifications display in-app
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions for proximity alerts
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                print("[AppDelegate] Notification permission error: \(error.localizedDescription)")
            }
            print("[AppDelegate] Notification permission granted: \(granted)")
        }

        // Log if we were launched due to BLE state restoration
        if let centralIDs = launchOptions?[.bluetoothCentrals] as? [String] {
            print("[AppDelegate] Launched for BLE central restoration: \(centralIDs)")
        }
        if let peripheralIDs = launchOptions?[.bluetoothPeripherals] as? [String] {
            print("[AppDelegate] Launched for BLE peripheral restoration: \(peripheralIDs)")
        }

        return true
    }

    // Show notification banners even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct NameTagApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([LocalProfile.self, LocalContact.self,
                                LocalConversation.self, LocalMessage.self])
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
    }
}
