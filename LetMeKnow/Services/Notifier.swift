import Foundation
import UserNotifications

/// Notifications for new incident reports on campus, posted from the live feed while the app is
/// open or was recently in the background.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    /// Asks once; returns whether notifications are allowed.
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func notify(about report: Report) {
        let content = UNMutableNotificationContent()
        content.title = report.title ?? "New incident report"
        content.subtitle = report.placeName.map { "Near \($0)" } ?? ""
        content.body = report.description
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: report.id.uuidString, content: content, trigger: nil))
    }

    /// Show the banner even when the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
