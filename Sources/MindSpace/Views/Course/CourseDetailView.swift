import SwiftUI
import SwiftData

/// Course detail with plain progress, availability, and a clear next session.
public struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    @ObservedObject private var syncService = GitHubSyncService.shared
    
    public let course: CatalogCourse
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var favorites: [FavoriteItem]
    
    @State private var isShowingBridgeSheet: Bool = false
    @State private var isShowingDownloadAlert: Bool = false
    @State private var downloadAlertMessage: String = ""

    
    public init(course: CatalogCourse) {
        self.course = course
    }
    
    private var completedSessionIDs: Set<String> {
        Set(completionEvents.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
    }
    
    private var completedCount: Int {
        course.sessions.filter { completedSessionIDs.contains($0.id) }.count
    }
    
    private var nextSession: CatalogSession? {
        course.sessions.first(where: { !completedSessionIDs.contains($0.id) }) ?? course.sessions.first
    }
    
    private var ambientColor: Color {
        MindSpaceTheme.accent(for: course.name)
    }
    
    private var isCourseFavorited: Bool {
        favorites.contains(where: { $0.sessionStableId == course.id })
    }
    
    public var body: some View {
        ZStack {
            MindSpaceTheme.background.ignoresSafeArea()
            
            // Restrained category tint; it is decorative and non-interactive.
            VStack {
                RadialGradient(
                    colors: [ambientColor.opacity(0.08), Color.clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 300
                )
                .frame(height: 280)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                Spacer()
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // MARK: - Navigation Bar
                    HStack {
                        Button(action: {
                            HapticService.shared.light()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.bold))
                                .foregroundStyle(MindSpaceTheme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(MindSpaceTheme.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                        }
                        .buttonStyle(.mindSpacePressable)
                        .accessibilityLabel("Back")
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(course.name)
                                .font(.headline)
                                .foregroundStyle(MindSpaceTheme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text("\(course.totalSessions) sessions • \(completedCount) completed")
                                .font(.caption)
                                .foregroundStyle(MindSpaceTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button(action: {
                                HapticService.shared.medium()
                                toggleCourseFavorite()
                            }) {
                                Label(isCourseFavorited ? "Remove from Favorites" : "Add to Favorites", systemImage: isCourseFavorited ? "star.fill" : "star")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.body.weight(.bold))
                                .foregroundStyle(MindSpaceTheme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(MindSpaceTheme.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Course summary
                    HStack(spacing: 16) {
                        MindSpaceCourseBadge(name: course.name, size: 56)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Guided course")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(ambientColor)
                                .textCase(.uppercase)
                                .tracking(0.8)
                            
                            Text(course.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(MindSpaceTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text(course.description.isEmpty ? "Deep mindful training for mental clarity and peaceful presence." : course.description)
                                .font(.subheadline)
                                .foregroundStyle(MindSpaceTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ProgressView(value: Double(completedCount), total: Double(max(1, course.totalSessions)))
                                .tint(ambientColor)
                                .accessibilityLabel("Course progress")
                                .accessibilityValue("\(completedCount) of \(course.totalSessions) sessions")
                        }
                        
                        Spacer()
                    }
                    .mindSpaceEmphasisStyle(cornerRadius: 22, accentColor: ambientColor, padding: 18)
                    .padding(.horizontal, 20)
                    
                    // MARK: - On-Demand Course Download Banner (if not downloaded)
                    if !LibraryPathResolver.shared.isCourseAvailable(course: course) {
                        VStack(spacing: 10) {
                            if syncService.isSyncing && syncService.activeCourseId == course.id {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(MindSpaceTheme.success)
                                        Text("Downloading \(course.name)...")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(MindSpaceTheme.textPrimary)
                                        Spacer()
                                        Text("\(syncService.completedTracks)/\(syncService.totalTracks)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(MindSpaceTheme.completion)
                                    }
                                    
                                    ProgressView(value: syncService.progressFraction)
                                        .tint(MindSpaceTheme.success)
                                    
                                    HStack {
                                        Text("\(Int(syncService.progressFraction * 100))% complete")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(MindSpaceTheme.textSecondary)
                                        Spacer()
                                        Button("Cancel") {
                                            syncService.cancelSync()
                                        }
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.warning)
                                    }
                                }
                                .padding(14)
                                .mindSpaceCardStyle(cornerRadius: 16, borderColor: MindSpaceTheme.success.opacity(0.4), padding: 0)
                            } else {
                                let totalBytes = LibraryPathResolver.shared.courseTotalSizeBytes(course: course)
                                let formattedMB = String(format: "%.0f MB", Double(totalBytes) / (1024 * 1024))
                                
                                Button(action: {
                                    HapticService.shared.medium()
                                    if !syncService.isConfigured {
                                        downloadAlertMessage = "GitHub content repository and Personal Access Token (PAT) must be configured in Settings before downloading."
                                        isShowingDownloadAlert = true
                                    } else {
                                        syncService.downloadCourse(course: course)
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(MindSpaceTheme.success.opacity(0.18))
                                                .frame(width: 38, height: 38)
                                            Image(systemName: "icloud.and.arrow.down.fill")
                                                .font(.system(size: 17))
                                                .foregroundColor(MindSpaceTheme.success)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Download Course for Offline Play")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(MindSpaceTheme.textPrimary)
                                            Text("\(course.sessions.count) sessions • \(formattedMB)")
                                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                                .foregroundColor(MindSpaceTheme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("Download")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(MindSpaceTheme.success)
                                            .clipShape(Capsule())
                                    }
                                    .padding(12)
                                }
                                .buttonStyle(.mindSpacePressable)
                                .mindSpaceCardStyle(cornerRadius: 16, borderColor: MindSpaceTheme.success.opacity(0.3), padding: 0)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Primary Action Button
                    if let next = nextSession {
                        MindSpacePrimaryButton("Continue Day \(next.dayNumber)", systemImage: "play.fill") {
                            HapticService.shared.medium()
                            playSession(next)
                        }
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("course.continue")
                    }
                    
                    // MARK: - Intro Video Button (if available)
                    if let intro = course.introVideo {
                        Button(action: {
                            HapticService.shared.medium()
                            playIntroVideo(intro)
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(MindSpaceTheme.success.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(MindSpaceTheme.success)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Watch Course Intro Video")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.textPrimary)
                                    Text("Video overview & mindfulness principles")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(MindSpaceTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(MindSpaceTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.mindSpacePressable)
                        .mindSpaceCardStyle(cornerRadius: 18, borderColor: MindSpaceTheme.success.opacity(0.3), padding: 14)
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Course progress
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Course progress")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MindSpaceTheme.textPrimary)
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 10) {
                            ForEach(course.sessions) { session in
                                let isDone = completedSessionIDs.contains(session.id)
                                let isNext = session.id == nextSession?.id

                                if course.hasGapWaiver && session.dayNumber == 30 {
                                    Button {
                                        HapticService.shared.medium()
                                        isShowingBridgeSheet = true
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: "pause.circle")
                                                .font(.title3)
                                                .foregroundStyle(MindSpaceTheme.secondaryAccent)
                                                .frame(width: 44, height: 44)
                                                .accessibilityHidden(true)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("Reflection days")
                                                    .font(.body.weight(.semibold))
                                                    .foregroundStyle(MindSpaceTheme.textPrimary)
                                                Text("Days 27–29 · Prepare for Day 30")
                                                    .font(.subheadline)
                                                    .foregroundStyle(MindSpaceTheme.textSecondary)
                                            }

                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(MindSpaceTheme.textSecondary)
                                                .accessibilityHidden(true)
                                        }
                                        .mindSpaceCardStyle(padding: 12)
                                    }
                                    .buttonStyle(.mindSpacePressable)
                                    .padding(.horizontal, 20)
                                    .accessibilityLabel("Reflection days, Days 27 through 29, prepare for Day 30")
                                }
                                
                                Button(action: {
                                    HapticService.shared.medium()
                                    playSession(session)
                                }) {
                                    HStack(spacing: 14) {
                                        Text("\(session.dayNumber)")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(isDone ? MindSpaceTheme.background : (isNext ? MindSpaceTheme.background : MindSpaceTheme.textSecondary))
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(isDone ? MindSpaceTheme.completion : (isNext ? MindSpaceTheme.accent : MindSpaceTheme.elevatedSurface))
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(session.title)
                                                .font(.body.weight(isNext ? .bold : .medium))
                                                .foregroundStyle(MindSpaceTheme.textPrimary)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            HStack(spacing: 6) {
                                                Text(session.condensedDuration)
                                                    .font(.subheadline)
                                                    .foregroundStyle(MindSpaceTheme.textSecondary)
                                                
                                                if !(session.videoAttachments ?? []).isEmpty {
                                                    Text("Video included")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(MindSpaceTheme.success)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if isDone {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(MindSpaceTheme.completion)
                                        } else if isNext {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(MindSpaceTheme.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(isNext ? MindSpaceTheme.accent.opacity(0.12) : MindSpaceTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(isNext ? MindSpaceTheme.accent.opacity(0.5) : MindSpaceTheme.divider, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.mindSpacePressable)
                                .padding(.horizontal, 20)
                                .accessibilityIdentifier("course.session.\(session.id)")
                            }
                        }
                    }
                    
                    Spacer(minLength: 90)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingBridgeSheet) {
            bridgeReflectionSheet
        }
        .alert("MindSpace Offline Content", isPresented: $isShowingDownloadAlert) {
            if !syncService.isConfigured {
                Button("OK", role: .cancel) {}
            } else {
                Button("Download Now") {
                    syncService.downloadCourse(course: course)
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            Text(downloadAlertMessage)
        }
    }
    
    private var bridgeReflectionSheet: some View {
        NavigationStack {
            ZStack {
                MindSpaceTheme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(MindSpaceTheme.secondaryAccent.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "pause")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(MindSpaceTheme.secondaryAccent)
                    }
                    .accessibilityHidden(true)
                    
                    Text("Reflection days")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MindSpaceTheme.textPrimary)
                    
                    Text("Days 27–29 · Pause and reflect")
                        .font(.headline)
                        .foregroundStyle(MindSpaceTheme.completion)
                    
                    Text("Take a peaceful moment to integrate everything you have practiced across Days 1–26 before stepping into Day 30. Your course progress remains unbroken.")
                        .font(.body)
                        .foregroundStyle(MindSpaceTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    MindSpacePrimaryButton("Continue to Day 30", systemImage: "play.fill") {
                        isShowingBridgeSheet = false
                        if let day30 = course.sessions.first(where: { $0.dayNumber == 30 }) {
                            playSession(day30)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingBridgeSheet = false
                    }
                    .foregroundStyle(MindSpaceTheme.accent)
                }
            }
        }
    }
    
    private func playSession(_ session: CatalogSession) {
        if !LibraryPathResolver.shared.isFileAvailable(relativePath: session.relativePath) {
            HapticService.shared.warning()
            if !syncService.isConfigured {
                downloadAlertMessage = "This session '\(session.title)' is not downloaded yet. Please configure your GitHub PAT in Settings to enable offline syncing."
                isShowingDownloadAlert = true
            } else {
                downloadAlertMessage = "This session '\(session.title)' is not downloaded yet. Would you like to download \(course.name) now?"
                isShowingDownloadAlert = true
            }
            return
        }
        
        let videoAttachment = session.videoAttachments?.first
        let track = PlayableTrack(
            id: session.id,
            title: session.title,
            courseName: course.name,
            relativePath: session.relativePath,
            duration: session.duration,
            videoAttachmentPath: videoAttachment?.relativePath,
            dayNumber: session.dayNumber,
            videoDuration: videoAttachment?.duration,
            contentType: "meditation"
        )
        playbackEngine.loadAndPlay(track: track)
        playbackEngine.isFullPlayerPresented = true
    }
    
    private func playIntroVideo(_ intro: VideoAttachment) {
        if !LibraryPathResolver.shared.isFileAvailable(relativePath: intro.relativePath) {
            HapticService.shared.warning()
            if !syncService.isConfigured {
                downloadAlertMessage = "Intro video is not downloaded yet. Please configure your GitHub PAT in Settings."
                isShowingDownloadAlert = true
            } else {
                downloadAlertMessage = "Intro video is not downloaded yet. Would you like to download \(course.name) now?"
                isShowingDownloadAlert = true
            }
            return
        }
        
        let track = PlayableTrack(
            id: intro.id,
            title: intro.title,
            courseName: course.name,
            relativePath: intro.relativePath,
            duration: intro.duration,
            videoAttachmentPath: intro.relativePath,
            videoDuration: intro.duration,
            contentType: "video"
        )
        playbackEngine.loadAndPlay(track: track)
        playbackEngine.isFullPlayerPresented = true
    }

    
    private func toggleCourseFavorite() {
        if let existing = favorites.first(where: { $0.sessionStableId == course.id }) {
            modelContext.delete(existing)
        } else {
            let fav = FavoriteItem(
                sessionStableId: course.id,
                title: course.name,
                relativePath: course.folderName
            )
            modelContext.insert(fav)
        }
        try? modelContext.save()
    }
    
}
