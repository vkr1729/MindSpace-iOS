import SwiftUI
import SwiftData

/// Screen 3: Course View (Canonical Blueprint)
/// Reference: Mock Screen Codex.png (Screen 3: Managing Anxiety)
public struct CourseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    public let course: CatalogCourse
    
    @Query(sort: \CompletionEvent.timestamp, order: .reverse) private var completionEvents: [CompletionEvent]
    
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
            
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Navigation Bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(course.name)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(CosmosTheme.textPrimary)
                            
                            Text("\(course.totalSessions) sessions")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            Button(action: {}) {
                                Label("Add to Favorites", systemImage: "star")
                            }
                            Button(action: {}) {
                                Label("Course Details", systemImage: "info.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(CosmosTheme.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Progress Banner
                    HStack {
                        Text("Your progress: \(completedCount) of \(course.totalSessions)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(CosmosTheme.moonLavender)
                        
                        Spacer()
                        
                        if course.hasGapWaiver {
                            Text("Bridge of Reflection ✨")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.starlightGold)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Interactive Constellation Path (Top Half)
                    CosmicCard(padding: 16) {
                        VStack(spacing: 12) {
                            ConstellationPathView(
                                nodes: constellationNodes,
                                onSelectNode: { node in
                                    if let session = course.sessions.first(where: { $0.id == node.id }) {
                                        playSession(session)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Primary Action Button
                    if let next = nextSession {
                        CosmicPrimaryButton("Continue Day \(next.dayNumber) ▶") {
                            playSession(next)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Intro Video Button (if available)
                    if let intro = course.introVideo {
                        Button(action: {
                            playIntroVideo(intro)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(CosmosTheme.auroraTeal)
                                
                                Text("Watch Course Intro Video")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(CosmosTheme.textSecondary)
                            }
                            .padding(16)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Session List (Bottom Half)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sessions")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .padding(.horizontal, 20)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(course.sessions) { session in
                                let isDone = completedSessionIDs.contains(session.id)
                                let isNext = session.id == nextSession?.id
                                
                                Button(action: {
                                    playSession(session)
                                }) {
                                    HStack(spacing: 14) {
                                        Text("\(session.dayNumber)")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(isNext ? CosmosTheme.cosmicPurple : (isDone ? CosmosTheme.starlightGold : CosmosTheme.textDisabled))
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.title)
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(isDone ? CosmosTheme.textSecondary : CosmosTheme.textPrimary)
                                            
                                            if let vCount = session.videoAttachments?.count, vCount > 0 {
                                                Text("Includes Video • \(session.formattedDuration)")
                                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                                    .foregroundColor(CosmosTheme.auroraTeal)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(session.formattedDuration)
                                            .font(.system(size: 14, weight: .regular, design: .rounded))
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
                                    .padding(.vertical, 14)
                                    .background(isNext ? CosmosTheme.spaceCard.opacity(0.9) : CosmosTheme.spaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(isNext ? CosmosTheme.cosmicPurple.opacity(0.6) : CosmosTheme.spaceCardBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    
                    Spacer(minLength: 80)
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
}
