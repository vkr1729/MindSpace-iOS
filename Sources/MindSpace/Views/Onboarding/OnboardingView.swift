import SwiftUI
import SwiftData

public struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: Int = 0
    @State private var selectedGoals: Set<String> = ["Stress", "Focus", "Sleep"]
    @State private var defaultDuration: Int = 10
    @State private var reminderEnabled: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var hasAcknowledgedDisclaimer: Bool = false
    
    let availableGoals = [
        "Learn", "Stress", "Sleep", "Focus",
        "Happiness", "Difficult Moments", "Work", "Sport"
    ]
    
    let durationOptions = [5, 10, 15, 20]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            CosmosTheme.spaceBackground.ignoresSafeArea()
            StarsBackgroundView()
            
            VStack(spacing: 24) {
                // MARK: - Progress Dots
                HStack(spacing: 8) {
                    ForEach(0..<5) { step in
                        Capsule()
                            .fill(step == currentStep ? CosmosTheme.starlightGold : (step < currentStep ? CosmosTheme.cosmicPurple : CosmosTheme.spaceCardBorder))
                            .frame(width: step == currentStep ? 24 : 8, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 20)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step \(currentStep + 1) of 5")
                
                // MARK: - Step Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    goalsStep.tag(1)
                    durationStep.tag(2)
                    contentSetupStep.tag(3)
                    disclaimerStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // MARK: - Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            HapticService.shared.light()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                                )
                        }
                    }
                    
                    Button(action: {
                        HapticService.shared.medium()
                        if currentStep < 4 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentStep == 4 ? "Enter MindSpace" : "Continue")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.spaceBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                (currentStep == 4 && !hasAcknowledgedDisclaimer) ?
                                AnyShapeStyle(CosmosTheme.spaceCardBorder) :
                                AnyShapeStyle(
                                    LinearGradient(
                                        colors: [CosmosTheme.starlightGold, CosmosTheme.solarCoral],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: (currentStep == 4 && !hasAcknowledgedDisclaimer) ? Color.clear : CosmosTheme.starlightGold.opacity(0.3), radius: 10)
                    }
                    .disabled(currentStep == 4 && !hasAcknowledgedDisclaimer)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Step 1: Welcome & Zero-Network Guarantee
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(CosmosTheme.cosmicPurple.opacity(0.2))
                    .frame(width: 110, height: 110)
                CelestialPlanetView(style: .purpleRinged, size: 74, hasRings: true)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to MindSpace")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Your private, account-free offline sanctuary for mindful living and meditation.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            CosmicCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 22))
                            .foregroundColor(CosmosTheme.auroraTeal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("100% Zero-Network Guarantee")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            Text("No accounts, no analytics, no third-party trackers, and no internet access. Works completely in Airplane Mode.")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Goal Selection
    private var goalsStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("What brings you here?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text("Choose areas you'd like to explore. You can change these anytime.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(availableGoals, id: \.self) { goal in
                        let isSelected = selectedGoals.contains(goal)
                        Button(action: {
                            HapticService.shared.selection()
                            if isSelected {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isSelected ? CosmosTheme.starlightGold : CosmosTheme.textSecondary)
                                Text(goal)
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? CosmosTheme.textPrimary : CosmosTheme.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(isSelected ? CosmosTheme.cosmicPurple.opacity(0.3) : CosmosTheme.spaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? CosmosTheme.cosmicPurple : CosmosTheme.spaceCardBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Step 3: Duration & Reminder
    private var durationStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Practice Preferences")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text("Set your ideal session length and an optional daily reminder.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Preferred Daily Duration")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                    .padding(.horizontal, 24)
                
                HStack(spacing: 10) {
                    ForEach(durationOptions, id: \.self) { mins in
                        let isSelected = (defaultDuration == mins)
                        Button(action: {
                            HapticService.shared.selection()
                            defaultDuration = mins
                        }) {
                            Text("\(mins) min")
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? CosmosTheme.spaceBackground : CosmosTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isSelected ?
                                    AnyShapeStyle(CosmosTheme.starlightGold) :
                                    AnyShapeStyle(CosmosTheme.spaceCard)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(isSelected ? Color.clear : CosmosTheme.spaceCardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            CosmicCard(padding: 16) {
                VStack(spacing: 14) {
                    Toggle(isOn: $reminderEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Mindful Reminder")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            Text("Scheduled 100% locally via iOS system clock.")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                    }
                    .tint(CosmosTheme.cosmicPurple)
                    
                    if reminderEnabled {
                        Divider().background(CosmosTheme.spaceCardBorder)
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .foregroundColor(CosmosTheme.textPrimary)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 4: Content & Storage Setup
    private var contentSetupStep: some View {
        let storageSize = LibraryPathResolver.shared.getLibraryStorageSizeBytes()
        let sizeMB = Double(storageSize) / (1024 * 1024)
        
        return VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "externaldrive.badge.icloud")
                .font(.system(size: 54))
                .foregroundColor(CosmosTheme.celestialBlue)
            
            VStack(spacing: 8) {
                Text("Offline Media Storage")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text("MindSpace reads audio and video from your sandboxed Documents/MindSpaceLibrary/ folder.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            CosmicCard(padding: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Library Status:")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                        Spacer()
                        Text(storageSize > 0 ? String(format: "%.1f MB active", sizeMB) : "No files copied yet")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(storageSize > 0 ? CosmosTheme.auroraTeal : CosmosTheme.moonLavender)
                    }
                    
                    Text("You can transfer your 15.81 GB media library anytime via USB or the iOS Files app. You can also preview courses and browse the entire catalog offline immediately.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 5: Medical & Wellness Disclaimer
    private var disclaimerStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Wellness Disclaimer")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(CosmosTheme.textPrimary)
                
                Text("Please review and acknowledge before entering.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
            }
            .padding(.top, 12)
            
            CosmicCard(padding: 16) {
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Important Health & Safety Notice")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.starlightGold)
                        
                        Text("MindSpace provides self-guided mindfulness meditation, breathing exercises, and relaxation audio for general wellbeing and stress management. MindSpace is NOT a medical device, diagnosis, clinical therapy, or healthcare provider.\n\nMeditation and mindfulness are complementary wellness practices and are not intended to diagnose, treat, cure, or prevent any mental or physical illness, psychiatric condition, or clinical disorder. If you are experiencing severe depression, anxiety, panic disorder, trauma, or psychiatric distress, please consult a licensed healthcare professional.\n\nNever listen to meditation tracks or sleep sounds while driving, operating machinery, or performing any activity requiring active attention.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding(.horizontal, 20)
            
            Button(action: {
                HapticService.shared.selection()
                hasAcknowledgedDisclaimer.toggle()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: hasAcknowledgedDisclaimer ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(hasAcknowledgedDisclaimer ? CosmosTheme.starlightGold : CosmosTheme.textSecondary)

                    Text("I have read and agree to the wellness disclaimer")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .accessibilityAddTraits(hasAcknowledgedDisclaimer ? [.isButton, .isSelected] : [.isButton])
            .accessibilityLabel("Agree to the wellness disclaimer")
            .accessibilityValue(hasAcknowledgedDisclaimer ? "Agreed" : "Not agreed")
            
            Spacer()
        }
    }
    
    private func completeOnboarding() {
        let settings = SettingsStore.fetchOrCreate(in: modelContext)
        settings.hasCompletedOnboarding = true
        settings.hasAcknowledgedDisclaimer = true
        settings.selectedGoals = Array(selectedGoals)
        settings.defaultDurationMinutes = defaultDuration
        
        let timeStr = DateFormatterCache.timeString(from: reminderTime)
        settings.reminderTime = timeStr
        
        if reminderEnabled {
            Task {
                let granted = await NotificationScheduler.shared.requestAuthorization()
                if granted {
                    settings.reminderEnabled = true
                    NotificationScheduler.shared.scheduleDailyReminder(timeString: timeStr, enabled: true)
                } else {
                    settings.reminderEnabled = false
                }
                try? modelContext.save()
            }
        } else {
            settings.reminderEnabled = false
            NotificationScheduler.shared.scheduleDailyReminder(timeString: timeStr, enabled: false)
            try? modelContext.save()
        }
        
        dismiss()
    }
}
