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
    @State private var showDeniedAlert: Bool = false
    
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
                MindSpaceTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Header Icon & Title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(MindSpaceTheme.accent.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [MindSpaceTheme.warning, MindSpaceTheme.secondaryAccent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .padding(.top, 16)
                            
                            Text("Daily Mindful Reminder")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                            
                            Text("A gentle local notification to support your meditation habit each day.")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // MARK: - Permission Denied Alert Banner
                        if permissionStatus == .denied {
                            MindSpaceCard(padding: 14) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(MindSpaceTheme.danger)
                                            .font(.system(size: 18))
                                        
                                        Text("Notifications Disabled in iOS")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(MindSpaceTheme.textPrimary)
                                    }
                                    
                                    Text("iOS notification permissions are turned off for MindSpace. Enable them in Settings to receive daily mindful reminders.")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.textSecondary)
                                    
                                    Button(action: {
                                        HapticService.shared.medium()
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        Text("Open iOS Settings")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(MindSpaceTheme.background)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(MindSpaceTheme.warning)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // MARK: - Main Toggle Card
                        MindSpaceCard(padding: 16) {
                            VStack(spacing: 16) {
                                Toggle(isOn: Binding(
                                    get: { isEnabled },
                                    set: { val in
                                        handleToggleChanged(val)
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Enable Daily Reminder")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(MindSpaceTheme.textPrimary)
                                        Text(isEnabled ? "Active on this iPhone" : "Reminders paused")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(isEnabled ? MindSpaceTheme.success : MindSpaceTheme.textSecondary)
                                    }
                                }
                                .tint(MindSpaceTheme.accent)
                                
                                if isEnabled {
                                    Divider().background(MindSpaceTheme.divider)
                                    
                                    // Time Picker
                                    DatePicker(
                                        "Reminder Time",
                                        selection: Binding(
                                            get: { reminderDate },
                                            set: { newDate in
                                                reminderDate = newDate
                                                HapticService.shared.selection()
                                                saveReminderSchedule(enabled: isEnabled, date: newDate)
                                            }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.compact)
                                    .foregroundColor(MindSpaceTheme.textPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - Quick Preset Times
                        if isEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Suggested Meditation Times")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textSecondary)
                                    .padding(.horizontal, 22)
                                
                                HStack(spacing: 8) {
                                    presetPill("8:00 AM", hour: 8, minute: 0)
                                    presetPill("1:00 PM", hour: 13, minute: 0)
                                    presetPill("9:00 PM", hour: 21, minute: 0)
                                    presetPill("10:30 PM", hour: 22, minute: 30)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // MARK: - Privacy Guarantee Card
                        MindSpaceCard(padding: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(MindSpaceTheme.success)
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("100% Offline Notification")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.textPrimary)
                                    Text("Scheduled locally via iOS system clock. No tracking or servers.")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if showSavedToast {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(MindSpaceTheme.success)
                                Text("Reminder schedule updated")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(MindSpaceTheme.elevatedSurface)
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
                    .foregroundColor(MindSpaceTheme.secondaryAccent)
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
                saveReminderSchedule(enabled: isEnabled, date: date)
            }
        }) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(MindSpaceTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MindSpaceTheme.elevatedSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(MindSpaceTheme.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.mindSpacePressable)
        .frame(minHeight: 44)
    }
    
    private func loadInitialState() {
        let settings = getOrCreateSettings()
        
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
            let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.permissionStatus = notificationSettings.authorizationStatus
                if notificationSettings.authorizationStatus == .authorized || notificationSettings.authorizationStatus == .provisional {
                    self.isEnabled = settings.reminderEnabled
                } else {
                    self.isEnabled = false
                    settings.reminderEnabled = false
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func handleToggleChanged(_ enabled: Bool) {
        if enabled {
            Task {
                let notifSettings = await UNUserNotificationCenter.current().notificationSettings()
                if notifSettings.authorizationStatus == .denied {
                    await MainActor.run {
                        self.permissionStatus = .denied
                        self.isEnabled = false
                        let settings = getOrCreateSettings()
                        settings.reminderEnabled = false
                        try? modelContext.save()
                        HapticService.shared.warning()
                    }
                    return
                }
                
                let granted = await NotificationScheduler.shared.requestAuthorization()
                await MainActor.run {
                    if granted {
                        self.permissionStatus = .authorized
                        self.isEnabled = true
                        saveReminderSchedule(enabled: true, date: reminderDate)
                    } else {
                        self.permissionStatus = .denied
                        self.isEnabled = false
                        let settings = getOrCreateSettings()
                        settings.reminderEnabled = false
                        try? modelContext.save()
                        HapticService.shared.warning()
                    }
                }
            }
        } else {
            self.isEnabled = false
            saveReminderSchedule(enabled: false, date: reminderDate)
        }
    }
    
    private func saveReminderSchedule(enabled: Bool, date: Date) {
        let timeStr = DateFormatterCache.timeString(from: date)
        let settings = getOrCreateSettings()
        settings.reminderEnabled = enabled
        settings.reminderTime = timeStr
        try? modelContext.save()
        
        NotificationScheduler.shared.scheduleDailyReminder(timeString: timeStr, enabled: enabled)
        
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
