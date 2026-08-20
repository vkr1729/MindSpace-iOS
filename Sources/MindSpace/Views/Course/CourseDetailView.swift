import SwiftUI
import SwiftData

/// Screen 3: Elevated Course View with Cinematic Celestial Hero & Living Constellation
/// Reference: Mock Screen Codex.png (Screen 3: Managing Anxiety)
public struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    public let course: CatalogCourse
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    @Query private var favorites: [FavoriteItem]
    
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
        CosmosTheme.ambientColor(for: course.name)
    }
    
    private var isCourseFavorited: Bool {
        favorites.contains(where: { $0.sessionStableId == course.id })
    }
    
    private var constellationNodes: [ConstellationNode] {
        let nextId = nextSession?.id
        return course.sessions.map { session in
            let isDone = completedSessionIDs.contains(session.id)
            let isAct = (session.id == nextId)
            let isBridge = course.hasGapWaiver && (session.dayNumber == 26)
            return ConstellationNode(
                id: session.id,
                dayNumber: session.dayNumber,
                title: session.title,
                isCompleted: isDone,
                isActive: isAct,
                isBridgeOfReflection: isBridge
            )
        }
    }
    
    public var body: some View {
        ZStack {
            CosmosTheme.spaceBackground.ignoresSafeArea()
            
            // Atmospheric Category Glow
            VStack {
                RadialGradient(
                    colors: [ambientColor.opacity(0.20), Color.clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 300
                )
                .frame(height: 280)
                .ignoresSafeArea()
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
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .frame(width: 42, height: 42)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.cosmicPressable)
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(course.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text("\(course.totalSessions) sessions • \(completedCount) completed")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
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
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .frame(width: 42, height: 42)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Course Spotlight Hero Card
                    HStack(spacing: 16) {
                        CelestialPlanetView(style: planetStyle(for: course.name), size: 68, hasRings: true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("GUIDED PATHWAY")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(ambientColor)
                                    .tracking(0.8)
                                
                                if course.hasGapWaiver {
                                    Text("Bridge Included ✨")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.starlightGold)
                                }
                            }
                            
                            Text(course.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text(course.description.isEmpty ? "Deep mindful training for mental clarity and peaceful presence." : course.description)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .cosmicHeroStyle(cornerRadius: 22, glowColor: ambientColor, padding: 18)
                    .padding(.horizontal, 20)
                    
                    // MARK: - Interactive Living Constellation Path
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Constellation Journey")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Spacer()
                            
                            Text("Tap node to play")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                        .padding(.horizontal, 4)
                        
                        ConstellationPathView(
                            nodes: constellationNodes,
                            onSelectNode: { node in
                                if let session = course.sessions.first(where: { $0.id == node.id }) {
                                    playSession(session)
                                }
                            }
                        )
                    }
                    .cosmicCardStyle(cornerRadius: 20, padding: 16)
                    .padding(.horizontal, 20)
                    
                    // MARK: - Primary Action Button
                    if let next = nextSession {
                        CosmicPrimaryButton("Continue Day \(next.dayNumber) ▶") {
                            HapticService.shared.medium()
                            playSession(next)
                        }
                        .padding(.horizontal, 20)
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
                                        .fill(CosmosTheme.auroraTeal.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(CosmosTheme.auroraTeal)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Watch Course Intro Video")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(CosmosTheme.textPrimary)
                                    Text("Video overview & mindfulness principles")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(CosmosTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.cosmicPressable)
                        .cosmicCardStyle(cornerRadius: 18, borderColor: CosmosTheme.auroraTeal.opacity(0.3), padding: 14)
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Session List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Sessions")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 10) {
                            ForEach(course.sessions) { session in
                                let isDone = completedSessionIDs.contains(session.id)
                                let isNext = session.id == nextSession?.id
                                
                                Button(action: {
                                    HapticService.shared.medium()
                                    playSession(session)
                                }) {
                                    HStack(spacing: 14) {
                                        Text("\(session.dayNumber)")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(isNext ? CosmosTheme.cosmicPurple : (isDone ? CosmosTheme.starlightGold : CosmosTheme.textDisabled))
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.title)
                                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                                .foregroundColor(isDone ? CosmosTheme.textSecondary : CosmosTheme.textPrimary)
                                            
                                            if let vCount = session.videoAttachments?.count, vCount > 0 {
                                                Text("Includes Video • \(session.formattedDuration)")
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundColor(CosmosTheme.auroraTeal)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(session.formattedDuration)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundColor(CosmosTheme.textSecondary)
                                        
                                        if isDone {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(CosmosTheme.starlightGold)
                                        } else {
                                            Image(systemName: isNext ? "play.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(isNext ? CosmosTheme.cosmicPurple : CosmosTheme.spaceCardBorder)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 13)
                                    .background(isNext ? CosmosTheme.spaceCard.opacity(0.9) : CosmosTheme.spaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(isNext ? CosmosTheme.cosmicPurple.opacity(0.6) : CosmosTheme.spaceCardBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.cosmicPressable)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Spacer(minLength: 90)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func playSession(_ session: CatalogSession) {
        let track = PlayableTrack(
            id: session.id,
            title: session.title,
            courseName: course.name,
            relativePath: session.relativePath,
            duration: session.duration,
            videoAttachmentPath: session.videoAttachments?.first?.relativePath,
            dayNumber: session.dayNumber
        )
        playbackEngine.loadAndPlay(track: track)
        playbackEngine.isFullPlayerPresented = true
    }
    
    private func playIntroVideo(_ intro: VideoAttachment) {
        let track = PlayableTrack(
            id: intro.id,
            title: intro.title,
            courseName: course.name,
            relativePath: intro.relativePath,
            duration: intro.duration,
            videoAttachmentPath: intro.relativePath
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
    
    private func planetStyle(for name: String) -> PlanetStyle {
        let lower = name.lowercased()
        if lower.contains("health") || lower.contains("anxiety") || lower.contains("stress") { return .auroraTeal }
        if lower.contains("happiness") || lower.contains("self-esteem") || lower.contains("relationships") { return .solarCoral }
        if lower.contains("work") || lower.contains("focus") || lower.contains("productivity") { return .electricBlue }
        if lower.contains("sleep") || lower.contains("night") || lower.contains("unwind") { return .crescentMoon }
        if lower.contains("brave") || lower.contains("grief") || lower.contains("anger") { return .brave }
        if lower.contains("student") { return .deepLavender }
        if lower.contains("pro") { return .pro }
        if lower.contains("sport") { return .sport }
        return .purpleRinged
    }
}
