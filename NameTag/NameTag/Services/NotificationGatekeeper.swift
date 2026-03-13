import Foundation
import UserNotifications

@Observable
final class NotificationGatekeeper {
    /// Whether the user is currently viewing the Nearby tab.
    var isOnNearbyTab: Bool = false

    /// Connection names for notification body text (UID -> display name)
    var connectionNames: [String: String] = [:]

    /// How long to suppress repeat notifications after one fires.
    var suppressionDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(suppressionDuration, forKey: NotificationSuppression.userDefaultsKey)
        }
    }

    /// UIDs mapped to the time their suppression expires.
    private var suppressedUntil: [String: Date] = [:]

    init() {
        let stored = UserDefaults.standard.double(forKey: NotificationSuppression.userDefaultsKey)
        suppressionDuration = stored > 0 ? stored : NotificationSuppression.defaultDuration
    }

    /// Attempt to send a notification for the given UID.
    func notifyIfAllowed(uid: String) {
        if isOnNearbyTab { return }

        if let expiration = suppressedUntil[uid] {
            if Date() < expiration { return }
            suppressedUntil.removeValue(forKey: uid)
        }

        let name = connectionNames[uid] ?? "Unknown"
        if suppressionDuration > 0 {
            suppressedUntil[uid] = Date().addingTimeInterval(suppressionDuration)
        }
        print("[NotificationGatekeeper] Sending notification for \(name) (\(uid))")
        sendLocalNotification(for: uid)
    }

    /// Cancel any pending/delivered notifications
    func cancelPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// Clear all state
    func reset() {
        suppressedUntil.removeAll()
        connectionNames.removeAll()
        isOnNearbyTab = false
    }

    // MARK: - Private

    private func sendLocalNotification(for uid: String) {
        let content = UNMutableNotificationContent()
        content.title = "NameTagger"
        content.body = if let name = connectionNames[uid] {
            "\(name) is nearby!"
        } else {
            "A contact is nearby!"
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "nearby-\(uid)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationGatekeeper] Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
