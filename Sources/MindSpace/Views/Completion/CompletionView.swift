import SwiftUI
import SwiftData

/// Quiet confirmation that a session was recorded, with the next action clear.
public struct CompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    @ObservedObject private var catalogService = CatalogService.shared
    
    public let completionId: UUID?
    public let sessionTitle: String
    public let courseName: String?
    public let durationMinutes: Int
    public let isQualifying: Bool
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var settingsList: [UserSettings]
    
    @State private var selectedReflection: String?
    
    public init(
        completionId: UUID? = nil,
        sessionTitle: String = "Basics — Day 4",
        courseName: String? = "Basics",
        durationMinutes: Int = 12,
        isQualifying: Bool = true
    ) {
        self.completionId = completionId
        self.sessionTitle = sessionTitle
        self.courseName = courseName
        self.durationMinutes = max(1, durationMinutes)
        self.isQualifying = isQualifying
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
    
    /// Resolves the next session in the active course (including Pregnancy gap waiver from Day 26 -> Day 30)
    private var nextCourseSession: (course: CatalogCourse, session: CatalogSession)? {
        guard let name = courseName,
              let manifest = catalogService.manifest else { return nil }
        
        for category in manifest.categories {
            if let course = category.courses.first(where: { $0.name == name }) {
                let completedIDs = Set(completionEvents.filter { $0.isQualifyingMeditation }.map { $0.sessionStableId })
                // If this is Pregnancy course and day 26 just completed, next is day 30
                if course.hasGapWaiver {
                    let uncompleted = course.sessions.filter { !completedIDs.contains($0.id) }
                    if let next = uncompleted.first {
                        return (course, next)
                    }
                } else {
                    let uncompleted = course.sessions.filter { !completedIDs.contains($0.id) }
                    if let next = uncompleted.first {
                        return (course, next)
                    }
                }
            }
        }
        return nil
    }
    
    public var body: some View {
        ZStack {
            MindSpaceTheme.background.ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    isQualifying ? MindSpaceTheme.completion.opacity(0.08) : MindSpaceTheme.accent.opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                // MARK: - Header
                HStack {
                    Spacer()
                    Button(action: {
                        HapticService.shared.light()
                        saveReflection()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(MindSpaceTheme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(MindSpaceTheme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                    }
                    .buttonStyle(.mindSpacePressable)
                    .accessibilityLabel("Close completion")
                    .accessibilityIdentifier("completion.close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                VStack(spacing: 6) {
                    Text(isQualifying ? "Practice complete" : "Session recorded")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(MindSpaceTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("\(durationMinutes) mindful \(durationMinutes == 1 ? "minute" : "minutes") recorded once")
                        .font(.headline)
                        .foregroundStyle(isQualifying ? MindSpaceTheme.completion : MindSpaceTheme.secondaryAccent)
                }
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((isQualifying ? MindSpaceTheme.completion : MindSpaceTheme.accent).opacity(0.12))
                            .frame(width: 96, height: 96)

                        Image(systemName: isQualifying ? "checkmark" : "leaf.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(isQualifying ? MindSpaceTheme.completion : MindSpaceTheme.secondaryAccent)
                    }
                    .frame(height: 120)
                    .accessibilityHidden(true)
                    
                    Text(isQualifying ? "Your progress is up to date." : "Every moment of awareness counts.")
                        .font(.body)
                        .foregroundStyle(MindSpaceTheme.textSecondary)
                }
                .padding(.vertical, 4)
                
                // MARK: - Milestone Progress Card
                MindSpaceCard(padding: 14) {
                    HStack(spacing: 14) {
                        Image(systemName: isQualifying ? "chart.line.uptrend.xyaxis" : "leaf")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isQualifying ? MindSpaceTheme.accent : MindSpaceTheme.secondaryAccent)
                            .frame(width: 44, height: 44)
                            .background((isQualifying ? MindSpaceTheme.accent : MindSpaceTheme.secondaryAccent).opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if isQualifying {
                                Text("\(orbitStats.currentStreak) of \(orbitStats.nextMilestoneDays) practice days")
                                    .font(.headline)
                                    .foregroundStyle(MindSpaceTheme.textPrimary)
                                
                                Text("Next milestone: \(orbitStats.nextMilestoneDays) days")
                                    .font(.subheadline)
                                    .foregroundStyle(MindSpaceTheme.textSecondary)
                            } else {
                                Text("\(orbitStats.currentStreak) mindful days")
                                    .font(.headline)
                                    .foregroundStyle(MindSpaceTheme.textPrimary)
                                
                                Text("Complete full sessions to build your practice streak")
                                    .font(.subheadline)
                                    .foregroundStyle(MindSpaceTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                
                // MARK: - Emotional Reflection Selector
                VStack(spacing: 10) {
                    Text("How are you feeling right now?")
                        .font(.body)
                        .foregroundStyle(MindSpaceTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        reflectionPill(title: "Lighter", tag: "lighter")
                        reflectionPill(title: "Centered", tag: "same")
                        reflectionPill(title: "Grounded", tag: "heavier")
                    }
                }
                .padding(.top, 4)
                
                Spacer()
                
                // MARK: - Action Buttons (Primary: Next session, Secondary: Done)
                VStack(spacing: 12) {
                    if let next = nextCourseSession {
                        Button(action: {
                            HapticService.shared.medium()
                            saveReflection()
                            dismiss()
                            
                            let nextTrack = PlayableTrack(
                                id: next.session.id,
                                title: next.session.title,
                                courseName: next.course.name,
                                relativePath: next.session.relativePath,
                                duration: next.session.duration,
                                videoAttachmentPath: next.session.videoAttachments?.first?.relativePath,
                                dayNumber: next.session.dayNumber,
                                contentType: "meditation"
                            )
                            playbackEngine.loadAndPlay(track: nextTrack)
                            playbackEngine.isFullPlayerPresented = true
                        }) {
                            HStack {
                                Text("Next session (Day \(next.session.dayNumber))")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.bold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(MindSpaceTheme.background)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(MindSpaceTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.mindSpacePrimaryPressable)
                    }
                    
                    Button(action: {
                        HapticService.shared.light()
                        saveReflection()
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(MindSpaceTheme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(MindSpaceTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(MindSpaceTheme.divider, lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("completion.done")
                    .buttonStyle(.mindSpacePressable)
                }
                .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            HapticService.shared.success()
        }
    }
    
    private func saveReflection() {
        guard let reflection = selectedReflection else { return }
        if let completionId = completionId {
            if let targetEvent = completionEvents.first(where: { $0.id == completionId }) {
                targetEvent.reflectionNote = reflection
                try? modelContext.save()
            }
        } else if let latest = completionEvents.first {
            latest.reflectionNote = reflection
            try? modelContext.save()
        }
    }
    
    @ViewBuilder
    private func reflectionPill(title: String, tag: String) -> some View {
        let isSel = (selectedReflection == tag)
        Button(action: {
            HapticService.shared.medium()
            selectedReflection = tag
            saveReflection()
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isSel ? .bold : .medium))
                    .foregroundStyle(isSel ? MindSpaceTheme.background : MindSpaceTheme.textPrimary)
                
                if isSel {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MindSpaceTheme.background)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(isSel ? MindSpaceTheme.completion : MindSpaceTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSel ? Color.clear : MindSpaceTheme.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.mindSpacePressable)
        .accessibilityLabel("Feeling \(title)")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }
}
