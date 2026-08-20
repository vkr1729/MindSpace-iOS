import SwiftUI
import SwiftData
import UserNotifications

/// Dedicated Mindful Daily Reminder Sheet for the Home screen bell icon
public struct MindfulReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]
    
    @State private var reminderDate: Date = Date()
    @State private var isEnabled: Bool = false
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSavedToast: Bool = false
    
    public init() {}
    
    private func getOrCreateSettings() -> UserSettings {
        if let existing = settingsList.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header Icon & Title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(CosmosTheme.cosmicPurple.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [CosmosTheme.starlightGold, CosmosTheme.moonLavender],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.top, 16)
                            
                            Text("Daily Mindful Reminder")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text("A gentle, 100% private offline chime to protect your meditation habit each day.")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // MARK: - Main Toggle Card
                        CosmicCard(padding: 16) {
                            VStack(spacing: 16) {
                                Toggle(isOn: Binding(
                                    get: { isEnabled },
                                    set: { val in
                                        isEnabled = val
                                        HapticService.shared.selection()
                                        saveSettings(enabled: val, date: reminderDate)
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Enable Daily Reminder")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        Text(isEnabled ? "Active on this iPhone" : "Reminders paused")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(isEnabled ? CosmosTheme.auroraTeal : CosmosTheme.textSecondary)
                                    }
                                }
                                .tint(CosmosTheme.cosmicPurple)
                                
                                if isEnabled {
                                    Divider().background(CosmosTheme.spaceCardBorder)
                                    
                                    // Time Picker
                                    DatePicker(
                                        "Reminder Time",
                                        selection: Binding(
                                            get: { reminderDate },
                                            set: { newDate in
                                                reminderDate = newDate
                                                HapticService.shared.selection()
                                                saveSettings(enabled: isEnabled, date: newDate)
                                            }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.compact)
                                    .foregroundColor(CosmosTheme.textPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Quick Preset Times
                        if isEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Suggested Meditation Times")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                                    .padding(.horizontal, 22)
                                
                                HStack(spacing: 8) {
                                    presetPill("🌅 08:00 AM", hour: 8, minute: 0)
                                    presetPill("☀️ 01:00 PM", hour: 13, minute: 0)
                                    presetPill("🌙 09:00 PM", hour: 21, minute: 0)
                                    presetPill("🌌 10:30 PM", hour: 22, minute: 30)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // MARK: - Privacy Guarantee Card
                        CosmicCard(padding: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(CosmosTheme.auroraTeal)
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("100% Offline Notification")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    Text("Scheduled locally via iOS system clock. No tracking or servers.")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if showSavedToast {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(CosmosTheme.auroraTeal)
                                Text("Reminder schedule updated")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(CosmosTheme.spacePill)
                            .clipShape(Capsule())
                            .transition(.opacity.combined(with: .scale))
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Mindful Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticService.shared.light()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(CosmosTheme.moonLavender)
                }
            }
            .onAppear {
                loadInitialState()
            }
        }
    }
    
    private func presetPill(_ label: String, hour: Int, minute: Int) -> some View {
        Button(action: {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = hour
            components.minute = minute
            if let date = Calendar.current.date(from: components) {
                reminderDate = date
                HapticService.shared.medium()
                saveSettings(enabled: isEnabled, date: date)
            }
        }) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(CosmosTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CosmosTheme.spacePill)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.cosmicPressable)
    }
    
    private func loadInitialState() {
        let settings = getOrCreateSettings()
        self.isEnabled = settings.reminderEnabled
        
        let parts = settings.reminderTime.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = h
            components.minute = m
            if let date = Calendar.current.date(from: components) {
                self.reminderDate = date
            }
        }
        
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.permissionStatus = settings.authorizationStatus
            }
        }
    }
    
    private func saveSettings(enabled: Bool, date: Date) {
        let timeStr = DateFormatterCache.timeString(from: date)
        
        let settings = getOrCreateSettings()
        settings.reminderEnabled = enabled
        settings.reminderTime = timeStr
        try? modelContext.save()
        
        Task {
            if enabled {
                let granted = await NotificationScheduler.shared.requestAuthorization()
                if granted {
                    NotificationScheduler.shared.scheduleDailyReminder(timeString: timeStr, enabled: true)
                }
            } else {
                NotificationScheduler.shared.scheduleDailyReminder(timeString: timeStr, enabled: false)
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSavedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showSavedToast = false
                    }
                }
            }
        }
    }
}
