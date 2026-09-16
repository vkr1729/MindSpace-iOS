import SwiftUI
import SwiftData

/// Screen 5: Elevated Completion Screen with Celebration Starburst & Tactile Reflections
/// Reference: Mock Screen Codex.png & UI/UX Pro Max Design Intelligence
public struct CompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var starScale: CGFloat = 0.8
    @State private var starOpacity: Double = 0.5
    
    @State private var reflectionSaveError: String?

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
            CosmosTheme.spaceBackground.ignoresSafeArea()
            StarsBackgroundView()
            
            // Atmospheric Celebration Glow
            RadialGradient(
                colors: [
                    isQualifying ? CosmosTheme.starlightGold.opacity(0.18) : CosmosTheme.cosmicPurple.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.cosmicPressable)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // MARK: - Celebration Title with Starlight Aura
                VStack(spacing: 6) {
                    Text(isQualifying ? "Orbit Continued" : "Session Recorded")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text("\(durationMinutes) Mindful \(durationMinutes == 1 ? "Minute" : "Minutes") Recorded")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(isQualifying ? CosmosTheme.starlightGold : CosmosTheme.moonLavender)
                }
                
                // MARK: - Constellation Arc Celebration Visual
                VStack(spacing: 12) {
                    ZStack {
                        // Pulsing outer halo
                        Circle()
                            .fill((isQualifying ? CosmosTheme.starlightGold : CosmosTheme.cosmicPurple).opacity(0.15))
                            .frame(width: 140, height: 140)
                            .scaleEffect(starScale)
                            .opacity(starOpacity)
                        
                        // Curved arc line
                        Circle()
                            .trim(from: 0.25, to: 0.75)
                            .stroke(
                                LinearGradient(
                                    colors: [CosmosTheme.cosmicPurple, CosmosTheme.starlightGold, CosmosTheme.solarCoral],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .frame(width: 190, height: 190)
                            .rotationEffect(.degrees(180))
                        
                        // Center Sparkling Star
                        Image(systemName: isQualifying ? "sparkle" : "leaf.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(isQualifying ? CosmosTheme.starlightGold : CosmosTheme.moonLavender)
                            .shadow(color: (isQualifying ? CosmosTheme.starlightGold : CosmosTheme.cosmicPurple).opacity(0.85), radius: 18)
                    }
                    .frame(height: 120)
                    
                    Text(isQualifying ? "You're building something beautiful." : "Every moment of awareness counts.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                }
                .padding(.vertical, 4)
                
                // MARK: - Milestone Progress Card
                CosmicCard(padding: 14) {
                    HStack(spacing: 14) {
                        CelestialPlanetView(style: isQualifying ? .goldenSun : .purpleRinged, size: 48, hasRings: !isQualifying)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if isQualifying {
                                Text("\(orbitStats.currentStreak) of \(orbitStats.nextMilestoneDays) Days Orbit")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Text("Next milestone: \(orbitStats.nextMilestoneDays) days")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            } else {
                                Text("\(orbitStats.currentStreak) Days Mindful")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Text("Complete full sessions to expand your Orbit")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                
                // MARK: - Emotional Reflection Selector
                VStack(spacing: 10) {
                    Text("How are you feeling right now?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)

                    HStack(spacing: 12) {
                        reflectionPill(title: "✨ Lighter", tag: "lighter")
                        reflectionPill(title: "🌱 Centered", tag: "same")
                        reflectionPill(title: "⚓ Grounded", tag: "heavier")
                    }

                    if let reflectionSaveError {
                        Text(reflectionSaveError)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(CosmosTheme.solarCoral)
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
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(CosmosTheme.cosmicPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: CosmosTheme.cosmicPurple.opacity(0.4), radius: 10, y: 4)
                        }
                        .buttonStyle(.cosmicPressable)
                    }
                    
                    Button(action: {
                        HapticService.shared.light()
                        saveReflection()
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.cosmicPressable)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            HapticService.shared.success()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                starScale = 1.25
                starOpacity = 0.85
            }
        }
    }
    
    private func saveReflection() {
        guard let reflection = selectedReflection else { return }
        reflectionSaveError = nil
        if let completionId = completionId {
            guard let targetEvent = completionEvents.first(where: { $0.id == completionId }) else {
                reflectionSaveError = "Couldn't attach your reflection — the session isn't in the store yet."
                return
            }
            targetEvent.reflectionNote = reflection
            do {
                try modelContext.save()
            } catch {
                reflectionSaveError = "Couldn't save your reflection. Please try again."
            }
        } else if let latest = completionEvents.first {
            latest.reflectionNote = reflection
            do {
                try modelContext.save()
            } catch {
                reflectionSaveError = "Couldn't save your reflection. Please try again."
            }
        } else {
            reflectionSaveError = "No session found to attach your reflection to."
        }
    }
    
    @ViewBuilder
    private func reflectionPill(title: String, tag: String) -> some View {
        let isSel = (selectedReflection == tag)
        Button(action: {
            HapticService.shared.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedReflection = tag
            }
            saveReflection()
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSel ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSel ? CosmosTheme.spaceBackground : CosmosTheme.textPrimary)
                
                if isSel {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CosmosTheme.spaceBackground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSel ?
                LinearGradient(
                    colors: [CosmosTheme.starlightGold, Color(hex: "#EAB308")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [CosmosTheme.spaceCard, CosmosTheme.spaceCard],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSel ? Color.clear : CosmosTheme.spaceCardBorder, lineWidth: 1)
            )
            .shadow(color: isSel ? CosmosTheme.starlightGold.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.cosmicPressable)
    }
}
