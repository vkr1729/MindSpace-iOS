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
    
    @State private var isShowingBridgeSheet: Bool = false
    
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
        var nodes: [ConstellationNode] = []
        
        if course.hasGapWaiver {
            // Pregnancy Course: Days 1-26, Bridge of Reflection (27-29), Day 30
            for session in course.sessions {
                let isDone = completedSessionIDs.contains(session.id)
                let isAct = (session.id == nextId)
                
                if session.dayNumber == 30 {
                    // Insert distinct Bridge of Reflection node between Day 26 and Day 30
                    let day26Done = course.sessions.first(where: { $0.dayNumber == 26 }).map { completedSessionIDs.contains($0.id) } ?? false
                    nodes.append(ConstellationNode(
                        id: "bridge_reflection_27_29",
                        dayNumber: 27,
                        title: "Bridge of Reflection",
                        isCompleted: day26Done,
                        isActive: false,
                        isBridgeOfReflection: true
                    ))
                }
                
                nodes.append(ConstellationNode(
                    id: session.id,
                    dayNumber: session.dayNumber,
                    title: session.title,
                    isCompleted: isDone,
                    isActive: isAct,
                    isBridgeOfReflection: false
                ))
            }
        } else {
            for session in course.sessions {
                let isDone = completedSessionIDs.contains(session.id)
                let isAct = (session.id == nextId)
                nodes.append(ConstellationNode(
                    id: session.id,
                    dayNumber: session.dayNumber,
                    title: session.title,
                    isCompleted: isDone,
                    isActive: isAct,
                    isBridgeOfReflection: false
                ))
            }
        }
        
        return nodes
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
                                if node.isBridgeOfReflection {
                                    HapticService.shared.medium()
                                    isShowingBridgeSheet = true
                                } else if let session = course.sessions.first(where: { $0.id == node.id }) {
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
                                            .foregroundColor(isDone ? CosmosTheme.starlightGold : (isNext ? CosmosTheme.cosmicPurple : CosmosTheme.textSecondary))
                                            .frame(width: 28, height: 28)
                                            .background(
                                                Circle()
                                                    .fill(isDone ? CosmosTheme.starlightGold.opacity(0.2) : (isNext ? CosmosTheme.cosmicPurple.opacity(0.2) : CosmosTheme.spaceCardBorder))
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(session.title)
                                                .font(.system(size: 15, weight: isNext ? .bold : .medium, design: .rounded))
                                                .foregroundColor(CosmosTheme.textPrimary)
                                                .lineLimit(1)
                                            
                                            HStack(spacing: 6) {
                                                Text(session.condensedDuration)
                                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                                    .foregroundColor(CosmosTheme.textSecondary)
                                                
                                                if !(session.videoAttachments ?? []).isEmpty {
                                                    Text("• Video Attached")
                                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                        .foregroundColor(CosmosTheme.auroraTeal)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if isDone {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(CosmosTheme.starlightGold)
                                        } else if isNext {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(CosmosTheme.cosmicPurple)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(isNext ? CosmosTheme.cosmicPurple.opacity(0.12) : CosmosTheme.spaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(isNext ? CosmosTheme.cosmicPurple.opacity(0.5) : CosmosTheme.spaceCardBorder, lineWidth: 1)
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
        .sheet(isPresented: $isShowingBridgeSheet) {
            bridgeReflectionSheet
        }
    }
    
    private var bridgeReflectionSheet: some View {
        NavigationStack {
            ZStack {
                CosmosTheme.spaceBackground.ignoresSafeArea()
                StarsBackgroundView()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(CosmosTheme.moonLavender.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundColor(CosmosTheme.moonLavender)
                    }
                    
                    Text("Bridge of Reflection")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                    
                    Text("Days 27–29: Mindful Transition & Reflection")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.starlightGold)
                    
                    Text("Take a peaceful moment to integrate everything you have practiced across Days 1–26 before stepping into Day 30. Your course progress remains unbroken.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    CosmicPrimaryButton("Continue to Day 30") {
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
                    .foregroundColor(CosmosTheme.moonLavender)
                }
            }
        }
    }
    
    private func playSession(_ session: CatalogSession) {
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
    
    private func planetStyle(for courseName: String) -> CelestialPlanetStyle {
        switch courseName.lowercased() {
        case let name where name.contains("basics"): return .purpleRinged
        case let name where name.contains("anxiety") || name.contains("stress"): return .solarCoral
        case let name where name.contains("health") || name.contains("pregnancy"): return .auroraTeal
        case let name where name.contains("focus") || name.contains("work"): return .electricBlue
        default: return .deepCosmos
        }
    }
}
