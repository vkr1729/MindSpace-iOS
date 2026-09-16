import SwiftUI

/// View displaying individual standalone meditation singles with hybrid streaming & selective downloads.
public struct SinglesListView: View {
    public let category: SinglesCategory
    public let onSelectSession: (SingleSession) -> Void
    
    @ObservedObject private var syncService = GitHubSyncService.shared
    
    public init(category: SinglesCategory, onSelectSession: @escaping (SingleSession) -> Void) {
        self.category = category
        self.onSelectSession = onSelectSession
    }
    
    private var isCategoryCompletelyDownloaded: Bool {
        category.sessions.allSatisfy { LibraryPathResolver.shared.isFileAvailable(relativePath: $0.relativePath) }
    }
    
    private var isCategoryCurrentlySyncing: Bool {
        return syncService.isSyncing && syncService.activeCourseId == category.id
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Banner with Category Download Control
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.name)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                            
                            Text(category.description)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(MindSpaceTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Category Download / Status Button
                        if isCategoryCurrentlySyncing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: MindSpaceTheme.success))
                                    .scaleEffect(0.85)
                                Text("\(Int(syncService.progressFraction * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.success)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(MindSpaceTheme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(MindSpaceTheme.success.opacity(0.3), lineWidth: 1))
                        } else if isCategoryCompletelyDownloaded {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(MindSpaceTheme.success)
                                Text("Offline")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.success)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(MindSpaceTheme.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(MindSpaceTheme.success.opacity(0.25), lineWidth: 1))
                        } else {
                            Button(action: {
                                HapticService.shared.medium()
                                syncService.downloadSinglesCategory(category: category)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Download All")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(MindSpaceTheme.warning)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(MindSpaceTheme.surface)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(MindSpaceTheme.warning.opacity(0.4), lineWidth: 1))
                            }
                            .buttonStyle(.mindSpacePressable)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                // Track List
                LazyVStack(spacing: 10) {
                    ForEach(category.sessions) { session in
                        let isDownloaded = LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath)
                        
                        Button(action: {
                            HapticService.shared.medium()
                            onSelectSession(session)
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: category.iconName.isEmpty ? "sparkles" : category.iconName)
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: category.colorHex))
                                    .frame(width: 34, height: 34)
                                    .background(
                                        Circle().fill(Color(hex: category.colorHex).opacity(0.15))
                                    )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.textPrimary)
                                    
                                    HStack(spacing: 6) {
                                        if let sub = session.subCategory {
                                            Text(sub)
                                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                                .foregroundColor(MindSpaceTheme.textSecondary)
                                        }
                                        
                                        // Status Chip
                                        if isDownloaded {
                                            HStack(spacing: 3) {
                                                Circle().fill(MindSpaceTheme.success).frame(width: 4, height: 4)
                                                Text("Downloaded")
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .foregroundColor(MindSpaceTheme.success)
                                            }
                                        } else {
                                            HStack(spacing: 3) {
                                                Circle().fill(MindSpaceTheme.warning).frame(width: 4, height: 4)
                                                Text("Stream Available")
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .foregroundColor(MindSpaceTheme.warning)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text(session.formattedDuration)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textSecondary)
                                
                                Image(systemName: isDownloaded ? "play.circle.fill" : "play.circle")
                                    .font(.system(size: 26))
                                    .foregroundColor(isDownloaded ? MindSpaceTheme.accent : MindSpaceTheme.warning)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(MindSpaceTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(MindSpaceTheme.divider, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.mindSpacePressable)
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer(minLength: 80)
            }
        }
        .background(MindSpaceTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
