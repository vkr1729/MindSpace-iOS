import Foundation
import UserNotifications

/// Handles scheduling local on-device meditation notifications without network permissions.
public final class NotificationScheduler: Sendable {
    public static let shared = NotificationScheduler()
    
    public init() {}
    
    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    public func scheduleDailyReminder(timeString: String, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_meditation_reminder"])
        
        guard enabled else { return }
        
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let content = UNMutableNotificationContent()
        content.title = "MindSpace"
        content.body = "Take a breath. Your daily practice is ready when you are."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_meditation_reminder", content: content, trigger: trigger)
        
        center.add(request) { _ in }
    }
}
