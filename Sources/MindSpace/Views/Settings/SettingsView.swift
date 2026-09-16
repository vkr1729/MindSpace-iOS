import SwiftUI
import SwiftData
import UserNotifications

/// Settings & Library Management Screen
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var catalogService = CatalogService.shared
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var favorites: [FavoriteItem]
    @Query(sort: \PlaybackResume.updatedAt, order: .reverse) private var resumes: [PlaybackResume]
    @Query private var settingsList: [UserSettings]
    @ObservedObject private var syncService = GitHubSyncService.shared
    
    @State private var exportURL: URL?
    @State private var activeSheet: ActiveSheet?
    @State private var pendingImportDocument: MindSpaceBackupDocument?
    @State private var importStatusMessage: String?
    @State private var isScanningLibrary = false
    @State private var isVerifyingChecksums = false
    @State private var verificationReport: LibraryVerificationReport?
    @State private var reminderDate: Date = Date()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private enum ActiveSheet: Identifiable {
        case share
        case documentPicker
        case disclaimer
        case importPreview(IdentifiableBackup)

        var id: String {
            switch self {
            case .share: return "share"
            case .documentPicker: return "documentPicker"
            case .disclaimer: return "disclaimer"
            case .importPreview(let wrapper): return "import-\(wrapper.id)"
            }
        }
    }

    private struct IdentifiableBackup: Identifiable {
        let id = UUID()
        let doc: MindSpaceBackupDocument
    }
    
    // GitHub Sync State
    @State private var githubRepoInput: String = ""
    @State private var githubPATInput: String = ""
    @State private var isPATVisible: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var connectionTestResult: (success: Bool, message: String)?

    @Binding private var path: NavigationPath

    public init(path: Binding<NavigationPath>? = nil) {
        if let path {
            _path = path
        } else {
            _path = .constant(NavigationPath())
        }
    }
    
    private func getOrCreateSettings() -> UserSettings {
        if let existing = settingsList.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }
    
    private var orbitStats: OrbitStats {
        let passes = settingsList.first?.compassionPassCount ?? 0
        let lastPassDate = settingsList.first?.lastUsedCompassionPassDate
        return OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: passes,
            lastUsedPassDate: lastPassDate
        )
    }
    
    private var storageSizeBytes: Int64 {
        LibraryPathResolver.shared.getLibraryStorageSizeBytes()
    }
    
    public var body: some View {
        ZStack {
            CosmosTheme.spaceBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Navigation Bar / Header
                    HStack {
                        Button(action: {
                            HapticService.shared.light()
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(CosmosTheme.moonLavender)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                        .padding(.horizontal, 20)
                    
                    // MARK: - Media Library Status Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Media Library")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .padding(.horizontal, 20)
                        
                        CosmicCard(padding: 16) {
                            VStack(spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Catalog Index")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        Text("\(catalogService.manifest?.totalFiles ?? 0) media files (275.99 hrs)")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(storageSizeBytes > 0 ? CosmosTheme.auroraTeal : CosmosTheme.solarCoral)
                                        .frame(width: 10, height: 10)
                                }
                                
                                Divider().background(CosmosTheme.spaceCardBorder)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Storage Location")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        Text("Documents/MindSpaceLibrary (iCloud backup excluded)")
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                    Spacer()
                                }
                                
                                HStack(spacing: 10) {
                                    Button(action: {
                                        rescanAndVerifyLibrary(validateChecksums: false)
                                    }) {
                                        HStack(spacing: 6) {
                                            if isScanningLibrary && !isVerifyingChecksums {
                                                ProgressView().tint(.white).scaleEffect(0.8)
                                                Text("Scanning...")
                                            } else {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                Text("Quick Scan")
                                            }
                                        }
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(CosmosTheme.spacePill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12).stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.cosmicPressable)
                                    .disabled(isScanningLibrary)
                                    
                                    Button(action: {
                                        rescanAndVerifyLibrary(validateChecksums: true)
                                    }) {
                                        HStack(spacing: 6) {
                                            if isScanningLibrary && isVerifyingChecksums {
                                                ProgressView().tint(.white).scaleEffect(0.8)
                                                Text("Verifying...")
                                            } else {
                                                Image(systemName: "checkmark.shield")
                                                Text("SHA-256 Audit")
                                            }
                                        }
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.starlightGold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(CosmosTheme.spacePill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12).stroke(CosmosTheme.starlightGold.opacity(0.4), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.cosmicPressable)
                                    .disabled(isScanningLibrary)
                                }
                                
                                // Detailed Verification Results Banner
                                if let report = verificationReport {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: report.isFullyVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                                .foregroundColor(report.isFullyVerified ? CosmosTheme.auroraTeal : CosmosTheme.solarCoral)
                                            Text(report.isFullyVerified ? "Library 100% Verified & Offline Ready" : "Library Verification Incomplete")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(report.isFullyVerified ? CosmosTheme.auroraTeal : CosmosTheme.solarCoral)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("• Total Catalog Tracks:")
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                Spacer()
                                                Text("\(report.totalTracks) tracks")
                                                    .foregroundColor(CosmosTheme.textPrimary)
                                                    .fontWeight(.semibold)
                                            }
                                            HStack {
                                                Text("• Verified On Disk:")
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                Spacer()
                                                Text("\(report.foundCount)")
                                                    .foregroundColor(report.foundCount == report.totalTracks ? CosmosTheme.auroraTeal : CosmosTheme.starlightGold)
                                                    .fontWeight(.semibold)
                                            }
                                            HStack {
                                                Text("• Missing Files:")
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                Spacer()
                                                Text("\(report.missingCount)")
                                                    .foregroundColor(report.missingCount == 0 ? CosmosTheme.auroraTeal : CosmosTheme.solarCoral)
                                                    .fontWeight(.semibold)
                                            }
                                            if report.sizeMismatchedCount > 0 {
                                                HStack {
                                                    Text("• Size Mismatches:")
                                                        .foregroundColor(CosmosTheme.textSecondary)
                                                    Spacer()
                                                    Text("\(report.sizeMismatchedCount)")
                                                        .foregroundColor(CosmosTheme.solarCoral)
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                            if report.checksumMismatchedCount > 0 {
                                                HStack {
                                                    Text("• Checksum Mismatches:")
                                                        .foregroundColor(CosmosTheme.textSecondary)
                                                    Spacer()
                                                    Text("\(report.checksumMismatchedCount)")
                                                        .foregroundColor(CosmosTheme.solarCoral)
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                            HStack {
                                                Text("• Offline Storage Hardening:")
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                Spacer()
                                                Text(report.isHardened ? "Protected (iCloud excluded & secure)" : "Not hardened")
                                                    .foregroundColor(report.isHardened ? CosmosTheme.starlightGold : CosmosTheme.solarCoral)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        .font(.system(size: 12, design: .rounded))
                                    }
                                    .padding(12)
                                    .background(CosmosTheme.spaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10).stroke(
                                            report.isFullyVerified ? CosmosTheme.auroraTeal.opacity(0.4) : CosmosTheme.solarCoral.opacity(0.4),
                                            lineWidth: 1
                                        )
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Private GitHub Content Sync
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Private GitHub Content Sync")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .padding(.horizontal, 20)
                        
                        CosmicCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Download and sync offline meditation courses directly from your private GitHub repository.")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                                
                                // Repository Input
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("GitHub Repository (owner/repo)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    
                                    HStack {
                                        Image(systemName: "folder.badge.gearshape")
                                            .foregroundColor(CosmosTheme.moonLavender)
                                        TextField("e.g. vkr1729/MindSpace-Content", text: $githubRepoInput)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    }
                                    .padding(10)
                                    .background(CosmosTheme.spacePill)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                                }
                                
                                // PAT Token Input
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Personal Access Token (PAT)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(CosmosTheme.starlightGold)
                                        
                                        if isPATVisible {
                                            TextField("ghp_... or github_pat_...", text: $githubPATInput)
                                                .font(.system(size: 14, design: .monospaced))
                                                .foregroundColor(CosmosTheme.textPrimary)
                                                .autocorrectionDisabled()
                                                .textInputAutocapitalization(.never)
                                        } else {
                                            SecureField("ghp_... or github_pat_...", text: $githubPATInput)
                                                .font(.system(size: 14, design: .monospaced))
                                                .foregroundColor(CosmosTheme.textPrimary)
                                                .autocorrectionDisabled()
                                                .textInputAutocapitalization(.never)
                                        }
                                        
                                        Button(action: { isPATVisible.toggle() }) {
                                            Image(systemName: isPATVisible ? "eye.slash" : "eye")
                                                .foregroundColor(CosmosTheme.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10)
                                    .background(CosmosTheme.spacePill)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                                }
                                
                                // Save & Test Connection Button
                                Button(action: {
                                    HapticService.shared.medium()
                                    syncService.savedRepo = githubRepoInput
                                    syncService.savedPAT = githubPATInput
                                    isTestingConnection = true
                                    connectionTestResult = nil
                                    Task {
                                        let res = await syncService.testConnection()
                                        await MainActor.run {
                                            self.isTestingConnection = false
                                            self.connectionTestResult = res
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        if isTestingConnection {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                            Text("Verifying Credentials...")
                                        } else {
                                            Image(systemName: "externaldrive.badge.checkmark")
                                            Text("Save & Test Connection")
                                        }
                                    }
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(CosmosTheme.cosmicPurple)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.cosmicPressable)
                                .disabled(isTestingConnection || syncService.isSyncing)
                                
                                // Connection Result Alert/Banner
                                if let result = connectionTestResult {
                                    HStack(spacing: 8) {
                                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(result.success ? CosmosTheme.auroraTeal : CosmosTheme.solarCoral)
                                        Text(result.message)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(result.success ? CosmosTheme.auroraTeal : CosmosTheme.solarCoral)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(CosmosTheme.spacePill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                Divider().background(CosmosTheme.spaceCardBorder)
                                
                                // Content Download Actions
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Content Download Actions")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    
                                    HStack(spacing: 10) {
                                        // Smart Sync Button
                                        Button(action: {
                                            HapticService.shared.medium()
                                            let settings = getOrCreateSettings()
                                            syncService.smartSync(goals: settings.selectedGoals)
                                        }) {
                                            VStack(spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "sparkles")
                                                    Text("Smart Sync")
                                                }
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(CosmosTheme.starlightGold)
                                                
                                                Text("Goal packs (~300 MB)")
                                                    .font(.system(size: 10, design: .rounded))
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(CosmosTheme.spacePill)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CosmosTheme.starlightGold.opacity(0.4), lineWidth: 1))
                                        }
                                        .buttonStyle(.cosmicPressable)
                                        .disabled(syncService.isSyncing || !syncService.isConfigured)
                                        
                                        // Download All Button
                                        Button(action: {
                                            HapticService.shared.medium()
                                            syncService.downloadAll()
                                        }) {
                                            VStack(spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                                    Text("Download All")
                                                }
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(CosmosTheme.auroraTeal)
                                                
                                                Text("Full library (15 GB)")
                                                    .font(.system(size: 10, design: .rounded))
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(CosmosTheme.spacePill)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CosmosTheme.auroraTeal.opacity(0.4), lineWidth: 1))
                                        }
                                        .buttonStyle(.cosmicPressable)
                                        .disabled(syncService.isSyncing || !syncService.isConfigured)
                                    }
                                }
                                
                                // Active Sync Progress Banner
                                if syncService.isSyncing {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .foregroundColor(CosmosTheme.auroraTeal)
                                            Text(syncService.currentTaskTitle)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(CosmosTheme.textPrimary)
                                            Spacer()
                                            Text("\(syncService.completedTracks)/\(syncService.totalTracks)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(CosmosTheme.starlightGold)
                                        }
                                        
                                        ProgressView(value: syncService.progressFraction)
                                            .tint(CosmosTheme.auroraTeal)
                                        
                                        HStack {
                                            Text("\(Int(syncService.progressFraction * 100))% complete")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundColor(CosmosTheme.textSecondary)
                                            Spacer()
                                            Button("Cancel") {
                                                syncService.cancelSync()
                                            }
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.solarCoral)
                                        }
                                    }
                                    .padding(12)
                                    .background(CosmosTheme.spacePill)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(CosmosTheme.auroraTeal.opacity(0.4), lineWidth: 1))
                                } else if let successMsg = syncService.lastSuccessMessage {
                                    Text(successMsg)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.auroraTeal)
                                } else if let errorMsg = syncService.lastErrorMessage {
                                    Text(errorMsg)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.solarCoral)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Progress Portability & Backup
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Progress Backup & Portability")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .padding(.horizontal, 20)
                        
                        CosmicCard(padding: 16) {
                            VStack(spacing: 12) {
                                Text("Seamlessly backup your completion history and streak to a .mindspace JSON file without accounts.")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        HapticService.shared.medium()
                                        exportProgress()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Export (.mindspace)")
                                        }
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(CosmosTheme.cosmicPurple)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.cosmicPressable)
                                    
                                    Button(action: {
                                        HapticService.shared.medium()
                                        activeSheet = .documentPicker
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "square.and.arrow.down")
                                            Text("Import Progress")
                                        }
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(CosmosTheme.spacePill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12).stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.cosmicPressable)
                                }
                                
                                if let msg = importStatusMessage {
                                    Text(msg)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(CosmosTheme.starlightGold)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Preferences & Reminders
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preferences")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .padding(.horizontal, 20)
                        
                        CosmicCard(padding: 16) {
                            VStack(spacing: 16) {
                                // Daily Orbit Reminder Toggle
                                Toggle(isOn: Binding(
                                    get: { settingsList.first?.reminderEnabled ?? false },
                                    set: { val in
                                        handleReminderToggle(val)
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Orbit Reminder")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        Text("Local notification on this iPhone")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                }
                                .tint(CosmosTheme.cosmicPurple)
                                
                                if notificationStatus == .denied {
                                    HStack {
                                        Text("Notifications are disabled in iOS Settings.")
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.solarCoral)
                                        Spacer()
                                        Button("Open Settings") {
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(CosmosTheme.starlightGold)
                                    }
                                    .padding(.top, 4)
                                }
                                
                                if settingsList.first?.reminderEnabled == true {
                                    Divider().background(CosmosTheme.spaceCardBorder)
                                    
                                    DatePicker(
                                        "Reminder Time",
                                        selection: Binding(
                                            get: { reminderDate },
                                            set: { newDate in
                                                reminderDate = newDate
                                                let timeStr = DateFormatterCache.timeString(from: newDate)
                                                let s = getOrCreateSettings()
                                                s.reminderTime = timeStr
                                                try? modelContext.save()
                                                HapticService.shared.selection()
                                                NotificationScheduler.shared.scheduleDailyReminder(timeString: timeStr, enabled: true)
                                            }
                                        ),
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.compact)
                                    .foregroundColor(CosmosTheme.textPrimary)
                                }
                                
                                Divider().background(CosmosTheme.spaceCardBorder)
                                
                                // Hide Streaks Toggle
                                Toggle(isOn: Binding(
                                    get: { settingsList.first?.hideStreak ?? false },
                                    set: { val in
                                        let s = getOrCreateSettings()
                                        s.hideStreak = val
                                        try? modelContext.save()
                                        HapticService.shared.selection()
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Hide Streaks & Orbit Counts")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        Text("Focus purely on presence without numbers")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                }
                                .tint(CosmosTheme.cosmicPurple)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Medical & Wellness Disclaimer Link
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Legal & Safety")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .padding(.horizontal, 20)
                        
                        CosmicCard(padding: 16) {
                            Button(action: {
                                HapticService.shared.light()
                                activeSheet = .disclaimer
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Medical & Wellness Disclaimer")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundColor(CosmosTheme.textPrimary)
                                        Text("Health notices, non-clinical scope & safe usage")
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Privacy & Zero Network Guarantee
                    CosmicCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(CosmosTheme.auroraTeal)
                                Text("Zero Network & 100% Private")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                            }
                            Text("MindSpace has no accounts, telemetry, ads, or network access. Your mindful practice never leaves this iPhone.")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            _ = getOrCreateSettings()
            syncReminderDateFromSettings()
            checkNotificationAuth()
            githubRepoInput = syncService.savedRepo
            githubPATInput = syncService.savedPAT
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkNotificationAuth()
            }
        }
        #if os(iOS)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .share:
                if let url = exportURL {
                    ShareSheetView(items: [url])
                }
            case .documentPicker:
                DocumentPickerView { url in
                    activeSheet = nil
                    handlePickedDocument(url: url)
                }
            case .disclaimer:
                wellnessDisclaimerSheet
            case .importPreview(let wrapper):
                ImportPreviewDialogView(
                    document: wrapper.doc,
                    onMerge: {
                        applyImport(document: wrapper.doc, isClean: false)
                        pendingImportDocument = nil
                        activeSheet = nil
                    },
                    onCleanRestore: {
                        applyImport(document: wrapper.doc, isClean: true)
                        pendingImportDocument = nil
                        activeSheet = nil
                    },
                    onCancel: {
                        pendingImportDocument = nil
                        activeSheet = nil
                    }
                )
            }
        }
        #endif
    }
    
    private var wellnessDisclaimerSheet: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Important Health & Safety Notice")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.starlightGold)
                        
                        Text("MindSpace provides self-guided mindfulness meditation, breathing exercises, and relaxation audio for general wellbeing and stress management. MindSpace is NOT a medical device, diagnosis, clinical therapy, or healthcare provider.\n\nMeditation and mindfulness are complementary wellness practices and are not intended to diagnose, treat, cure, or prevent any mental or physical illness, psychiatric condition, or clinical disorder. If you are experiencing severe depression, anxiety, panic disorder, trauma, or psychiatric distress, please consult a licensed healthcare professional.\n\nNever listen to meditation tracks or sleep sounds while driving, operating machinery, or performing any activity requiring active attention.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .lineSpacing(6)
                        
                        Spacer()
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Wellness Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        activeSheet = nil
                    }
                    .foregroundColor(CosmosTheme.moonLavender)
                }
            }
        }
    }
    
    private func checkNotificationAuth() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.notificationStatus = settings.authorizationStatus
                if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
                    let s = getOrCreateSettings()
                    if s.reminderEnabled {
                        s.reminderEnabled = false
                        try? modelContext.save()
                    }
                }
            }
        }
    }
    
    private func handleReminderToggle(_ val: Bool) {
        if val {
            Task {
                let notifSettings = await UNUserNotificationCenter.current().notificationSettings()
                if notifSettings.authorizationStatus == .denied {
                    await MainActor.run {
                        self.notificationStatus = .denied
                        let s = getOrCreateSettings()
                        s.reminderEnabled = false
                        try? modelContext.save()
                        HapticService.shared.warning()
                    }
                    return
                }
                
                let granted = await NotificationScheduler.shared.requestAuthorization()
                await MainActor.run {
                    let s = getOrCreateSettings()
                    if granted {
                        self.notificationStatus = .authorized
                        s.reminderEnabled = true
                        NotificationScheduler.shared.scheduleDailyReminder(timeString: s.reminderTime, enabled: true)
                        HapticService.shared.selection()
                    } else {
                        self.notificationStatus = .denied
                        s.reminderEnabled = false
                        HapticService.shared.warning()
                    }
                    try? modelContext.save()
                }
            }
        } else {
            let s = getOrCreateSettings()
            s.reminderEnabled = false
            NotificationScheduler.shared.scheduleDailyReminder(timeString: s.reminderTime, enabled: false)
            try? modelContext.save()
            HapticService.shared.selection()
        }
    }
    
    private func syncReminderDateFromSettings() {
        let s = getOrCreateSettings()
        let parts = s.reminderTime.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = h
            components.minute = m
            if let d = Calendar.current.date(from: components) {
                reminderDate = d
            }
        }
    }
    
    private func exportProgress() {
        let s = getOrCreateSettings()
        let doc = ProgressTransferManager.shared.createBackupDocument(
            events: completionEvents,
            favorites: favorites,
            settings: s,
            orbitStats: orbitStats,
            resumes: resumes
        )
        if let fileURL = try? ProgressTransferManager.shared.exportToFile(document: doc) {
            self.exportURL = fileURL
            self.activeSheet = .share
        }
    }
    
    private func handlePickedDocument(url: URL) {
        if let doc = try? ProgressTransferManager.shared.parseBackupDocument(from: url) {
            self.pendingImportDocument = doc
            self.activeSheet = .importPreview(IdentifiableBackup(doc: doc))
        } else {
            self.importStatusMessage = "Failed to parse .mindspace backup file."
        }
    }
    
    private func applyImport(document: MindSpaceBackupDocument, isClean: Bool) {
        do {
            try ProgressTransferManager.shared.applyImport(
                document: document,
                modelContext: modelContext,
                isCleanRestore: isClean
            )
            importStatusMessage = "Successfully imported \(document.completionEvents.count) sessions!"
        } catch {
            importStatusMessage = "Import error: \(error.localizedDescription)"
        }
    }
    
    private func rescanAndVerifyLibrary(validateChecksums: Bool) {
        isScanningLibrary = true
        isVerifyingChecksums = validateChecksums
        HapticService.shared.medium()
        
        LibraryPathResolver.shared.applyHardeningAndProtection()
        catalogService.loadCatalog()
        
        Task {
            let report = await LibraryPathResolver.shared.verifyAllCatalogEntries(
                manifest: catalogService.manifest,
                validateChecksums: validateChecksums
            )
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.verificationReport = report
                    self.isScanningLibrary = false
                    self.isVerifyingChecksums = false
                }
                
                if report.isFullyVerified {
                    HapticService.shared.success()
                } else {
                    HapticService.shared.warning()
                }
            }
        }
    }
}
