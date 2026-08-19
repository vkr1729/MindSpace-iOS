import SwiftUI
import SwiftData

/// Settings & Library Management Screen
public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var catalogService = CatalogService.shared
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var favorites: [FavoriteItem]
    @Query private var settingsList: [UserSettings]
    
    @State private var exportURL: URL?
    @State private var isShowingShareSheet = false
    @State private var isShowingDocumentPicker = false
    @State private var pendingImportDocument: MindSpaceBackupDocument?
    @State private var importStatusMessage: String?
    @State private var isScanningLibrary = false
    
    public init() {}
    
    private var currentSettings: UserSettings {
        settingsList.first ?? UserSettings()
    }
    
    private var orbitStats: OrbitStats {
        OrbitCalculator().calculateStats(
            events: completionEvents,
            existingCompassionPasses: currentSettings.compassionPassCount
        )
    }
    
    private var storageSizeBytes: Int64 {
        LibraryPathResolver.shared.getLibraryStorageSizeBytes()
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        Text("Settings")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        
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
                                        rescanLibrary()
                                    }) {
                                        HStack {
                                            if isScanningLibrary {
                                                ProgressView().tint(.white)
                                            } else {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                            }
                                            Text("Rescan & Verify Library")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(CosmosTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(CosmosTheme.spacePill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
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
                                        Button(action: { exportProgress() }) {
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
                                        .buttonStyle(.plain)
                                        
                                        Button(action: { isShowingDocumentPicker = true }) {
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
                                        .buttonStyle(.plain)
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
                        
                        // MARK: - Daily Reminders & Preferences
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Preferences")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                                .padding(.horizontal, 20)
                            
                            CosmicCard(padding: 16) {
                                VStack(spacing: 16) {
                                    Toggle(isOn: Binding(
                                        get: { currentSettings.reminderEnabled },
                                        set: { val in
                                            currentSettings.reminderEnabled = val
                                            try? modelContext.save()
                                            Task {
                                                if val {
                                                    _ = await NotificationScheduler.shared.requestAuthorization()
                                                }
                                                NotificationScheduler.shared.scheduleDailyReminder(
                                                    timeString: currentSettings.reminderTime,
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
                                    
                                    Divider().background(CosmosTheme.spaceCardBorder)
                                    
                                    Toggle(isOn: Binding(
                                        get: { currentSettings.hideStreak },
                                        set: { val in
                                            currentSettings.hideStreak = val
                                            try? modelContext.save()
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
    }
    
    private struct IdentifiableBackup: Identifiable {
        let id = UUID()
        let doc: MindSpaceBackupDocument
    }
    
    private func exportProgress() {
        let doc = ProgressTransferManager.shared.createBackupDocument(
            events: completionEvents,
            favorites: favorites,
            settings: currentSettings,
            orbitStats: orbitStats
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
    
    private func rescanLibrary() {
        isScanningLibrary = true
        LibraryPathResolver.shared.applyHardeningAndProtection()
        catalogService.loadCatalog()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isScanningLibrary = false
        }
    }
}
