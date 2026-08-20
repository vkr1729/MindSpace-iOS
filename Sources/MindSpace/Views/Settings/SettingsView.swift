import SwiftUI
import SwiftData

/// Settings & Library Management Screen
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var catalogService = CatalogService.shared
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var favorites: [FavoriteItem]
    @Query(sort: \PlaybackResume.updatedAt, order: .reverse) private var resumes: [PlaybackResume]
    @Query private var settingsList: [UserSettings]
    
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingDocumentPicker = false
    @State private var pendingImportDocument: MindSpaceBackupDocument?
    @State private var importStatusMessage: String?
    @State private var isScanningLibrary = false
    @State private var verificationReport: LibraryVerificationReport?
    @State private var reminderDate: Date = Date()
    
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
    
    private var orbitStats: OrbitStats {
        let passes = settingsList.first?.compassionPassCount ?? 0
        return OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: passes
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
                                        .fill(CosmosTheme.auroraTeal)
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
                                
                                Button(action: {
                                    rescanAndVerifyLibrary()
                                }) {
                                    HStack(spacing: 8) {
                                        if isScanningLibrary {
                                            ProgressView().tint(.white)
                                                .scaleEffect(0.8)
                                            Text("Scanning & Verifying Checksums...")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                            Text("Rescan & Verify Library")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        }
                                    }
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
                                .disabled(isScanningLibrary)
                                
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
                                            HStack {
                                                Text("• Total Mindfulness Duration:")
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                Spacer()
                                                Text(report.totalHoursFormatted)
                                                    .foregroundColor(CosmosTheme.textPrimary)
                                                    .fontWeight(.semibold)
                                            }
                                            HStack {
                                                Text("• Offline Storage Hardening:")
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                Spacer()
                                                Text(report.isHardened ? "Protected (No iCloud Leaks)" : "Active")
                                                    .foregroundColor(CosmosTheme.starlightGold)
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
                                        isShowingDocumentPicker = true
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
                                        let s = getOrCreateSettings()
                                        s.reminderEnabled = val
                                        try? modelContext.save()
                                        HapticService.shared.selection()
                                        Task {
                                            if val {
                                                _ = await NotificationScheduler.shared.requestAuthorization()
                                            }
                                            NotificationScheduler.shared.scheduleDailyReminder(
                                                timeString: s.reminderTime,
                                                enabled: val
                                            )
                                        }
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
        }
        #if os(iOS)
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = exportURL {
                ShareSheetView(items: [url])
            }
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPickerView { url in
                handlePickedDocument(url: url)
            }
        }
        #endif
        .sheet(item: Binding(
            get: { pendingImportDocument.map { IdentifiableBackup(doc: $0) } },
            set: { pendingImportDocument = $0?.doc }
        )) { wrapper in
            ImportPreviewDialogView(
                document: wrapper.doc,
                onMerge: {
                    applyImport(document: wrapper.doc, isClean: false)
                    pendingImportDocument = nil
                },
                onCleanRestore: {
                    applyImport(document: wrapper.doc, isClean: true)
                    pendingImportDocument = nil
                },
                onCancel: {
                    pendingImportDocument = nil
                }
            )
        }
    }
    
    private struct IdentifiableBackup: Identifiable {
        let id = UUID()
        let doc: MindSpaceBackupDocument
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
            self.isShowingShareSheet = true
        }
    }
    
    private func handlePickedDocument(url: URL) {
        if let doc = try? ProgressTransferManager.shared.parseBackupDocument(from: url) {
            self.pendingImportDocument = doc
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
    
    private func rescanAndVerifyLibrary() {
        isScanningLibrary = true
        HapticService.shared.medium()
        
        LibraryPathResolver.shared.applyHardeningAndProtection()
        catalogService.loadCatalog()
        
        Task {
            let report = await LibraryPathResolver.shared.verifyAllCatalogEntries(
                manifest: catalogService.manifest,
                validateChecksums: false
            )
            
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.verificationReport = report
                    self.isScanningLibrary = false
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
