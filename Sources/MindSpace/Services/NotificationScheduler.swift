import Foundation
import SwiftData
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
              let hour = Int(parts[0]), (0...23).contains(hour),
              let minute = Int(parts[1]), (0...59).contains(minute) else { return }
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let content = UNMutableNotificationContent()
        content.title = "MindSpace"
        content.body = "Take a breath. Your daily orbit is waiting for you."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_meditation_reminder", content: content, trigger: trigger)
        
        center.add(request) { _ in }
    }

    /// Reconciles the in-app reminder toggle with the real iOS authorization
    /// status (e.g. user revoked permission in Settings). Must be called on
    /// launch and when returning to foreground.
    @MainActor
    public func reconcileReminderSetting(modelContext: ModelContext) {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus != .authorized,
                  settings.authorizationStatus != .provisional else { return }
            let descriptor = FetchDescriptor<UserSettings>()
            if let current = try? modelContext.fetch(descriptor).first, current.reminderEnabled {
                current.reminderEnabled = false
                try? modelContext.save()
            }
        }
    }
}
