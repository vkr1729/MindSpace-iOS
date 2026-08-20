import SwiftUI
import SwiftData

/// Screen 4: Elevated Minimalist Meditation Player with Celestial Breathing Aura & Luminous Scrubber
/// Reference: Mock Screen Codex.png & UI/UX Pro Max Design Intelligence
public struct MeditationPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    @Query private var favorites: [FavoriteItem]
    
    @State private var isShowingCompletionSheet = false
    @State private var isFullScreenVideoPresented = false
    @State private var isScrubbing = false
    @State private var scrubbedTime: Double = 0.0
    @State private var isZenMode = false
    
    public init() {}
    
    private var track: PlayableTrack? {
        playbackEngine.currentTrack
    }
    
    private var isFavorite: Bool {
        guard let track = track else { return false }
        return favorites.contains(where: { $0.sessionStableId == track.id })
    }
    
    private var isPlaying: Bool {
        playbackEngine.state == .playing
    }
    
    private var displayCurrentTime: Double {
        isScrubbing ? scrubbedTime : playbackEngine.currentTime
    }
    
    private var duration: Double {
        playbackEngine.duration > 0 ? playbackEngine.duration : (track?.duration ?? 0.0)
    }
    
    private var ambientColor: Color {
        CosmosTheme.ambientColor(for: track?.courseName ?? "MindSpace")
    }
    
    public var body: some View {
        ZStack {
            // Deep cosmic background
            CosmosTheme.spaceBackground.ignoresSafeArea()
            
            // Atmospheric Ambient Spotlight
            RadialGradient(
                colors: [ambientColor.opacity(isPlaying ? 0.22 : 0.10), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 360
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.5), value: isPlaying)
            
            StarsBackgroundView()
            
            VStack(spacing: 20) {
                // MARK: - Navigation Bar
                HStack {
                    Button(action: {
                        HapticService.shared.light()
                        playbackEngine.isFullPlayerPresented = false
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.cosmicPressable)
                    
                    Spacer()
                    
                    VStack(spacing: 3) {
                        Text(track?.title ?? "Meditation")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(CosmosTheme.auroraTeal)
                                .frame(width: 6, height: 6)
                            Text("100% Offline")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                    }
                    .opacity(isZenMode ? 0.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isZenMode)
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        // Zen / Dim Mode Toggle
                        Button(action: {
                            HapticService.shared.light()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isZenMode.toggle()
                            }
                        }) {
                            Image(systemName: isZenMode ? "eye.fill" : "eye.slash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(isZenMode ? CosmosTheme.starlightGold : CosmosTheme.textSecondary)
                                .frame(width: 42, height: 42)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.cosmicPressable)
                        
                        // Favorite Star Button
                        Button(action: {
                            HapticService.shared.medium()
                            toggleFavorite()
                        }) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(isFavorite ? CosmosTheme.starlightGold : CosmosTheme.textPrimary)
                                .frame(width: 42, height: 42)
                                .background(CosmosTheme.spaceCard)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.cosmicPressable)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer()
                
                // MARK: - Central Visual Anchor with Mindful Breathing Aura
                ZStack {
                    if let videoRel = track?.videoAttachmentPath,
                       let _ = LibraryPathResolver.shared.resolveURL(for: videoRel) {
                        ZStack(alignment: .topTrailing) {
                            VideoPlayerView(player: playbackEngine.player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .cornerRadius(22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                                )
                                .shadow(color: ambientColor.opacity(0.35), radius: 20)
                                .onTapGesture {
                                    isFullScreenVideoPresented = true
                                }
                            
                            Button(action: {
                                isFullScreenVideoPresented = true
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(CosmosTheme.textPrimary)
                                    .padding(8)
                                    .background(CosmosTheme.spaceBackground.opacity(0.8))
                                    .clipShape(Circle())
                                    .padding(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        CelestialBreathingAuraView(
                            style: planetStyleForTrack,
                            ambientColor: ambientColor,
                            isPlaying: isPlaying
                        )
                    }
                }
                
                Spacer()
                
                // MARK: - Digital Time Readout & Scrubber
                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formatTime(displayCurrentTime))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .monospacedDigit()
                        
                        Text("/ of \(formatTime(duration))")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                    }
                    
                    // Luminous Touch-Responsive Scrubber
                    luminousScrubber
                }
                .opacity(isZenMode ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isZenMode)
                
                // MARK: - Transport Controls (Skip ±15s & Glowing Play/Pause)
                HStack(spacing: 36) {
                    // Skip Backward 15s
                    Button(action: {
                        HapticService.shared.light()
                        playbackEngine.skipBackward(15)
                    }) {
                        ZStack {
                            Circle()
                                .fill(CosmosTheme.spaceCard)
                                .frame(width: 52, height: 52)
                                .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                            
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(CosmosTheme.textPrimary)
                        }
                    }
                    .buttonStyle(.cosmicPressable)
                    
                    // Large Tactical Play / Pause Button
                    Button(action: {
                        HapticService.shared.medium()
                        playbackEngine.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [CosmosTheme.cosmicPurple, Color(hex: "#6344E0")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 78, height: 78)
                                .shadow(color: CosmosTheme.cosmicPurple.opacity(0.55), radius: 18, x: 0, y: 5)
                            
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .buttonStyle(.cosmicPrimaryPressable)
                    
                    // Skip Forward 15s
                    Button(action: {
                        HapticService.shared.light()
                        playbackEngine.skipForward(15)
                    }) {
                        ZStack {
                            Circle()
                                .fill(CosmosTheme.spaceCard)
                                .frame(width: 52, height: 52)
                                .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                            
                            Image(systemName: "goforward.15")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(CosmosTheme.textPrimary)
                        }
                    }
                    .buttonStyle(.cosmicPressable)
                }
                .padding(.top, 4)
                
                // MARK: - Bottom Tactile Pills (Speed & Sleep Timer)
                HStack(spacing: 16) {
                    // Speed Toggle Pill
                    Menu {
                        ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                            Button(action: {
                                HapticService.shared.selection()
                                playbackEngine.setSpeed(speed)
                            }) {
                                HStack {
                                    Text(speed.label)
                                    if playbackEngine.speed == speed {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(playbackEngine.speed.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Speed")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                        }
                        .foregroundColor(CosmosTheme.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                    }
                    
                    // Sleep Timer Pill
                    Menu {
                        Button("Off") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: nil)
                        }
                        Button("5 minutes") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: 5)
                        }
                        Button("10 minutes") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: 10)
                        }
                        Button("15 minutes") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: 15)
                        }
                        Button("30 minutes") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: 30)
                        }
                        Button("45 minutes") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: 45)
                        }
                        Button("60 minutes") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: 60)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "alarm")
                                .font(.system(size: 14))
                            if let remaining = playbackEngine.sleepTimerMinutesRemaining {
                                Text("\(remaining)m")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            } else {
                                Text("Timer")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                        }
                        .foregroundColor(playbackEngine.sleepTimerMinutesRemaining != nil ? CosmosTheme.starlightGold : CosmosTheme.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(playbackEngine.sleepTimerMinutesRemaining != nil ? CosmosTheme.starlightGold.opacity(0.6) : CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                    }
                }
                .opacity(isZenMode ? 0.3 : 1.0)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isShowingCompletionSheet) {
            if let info = playbackEngine.lastCompletionInfo {
                CompletionView(
                    completionId: info.completionId,
                    sessionTitle: info.track.title,
                    courseName: info.track.courseName,
                    durationMinutes: info.actualMinutes,
                    isQualifying: info.isQualifying
                )
            } else if let track = track {
                CompletionView(
                    sessionTitle: track.title,
                    courseName: track.courseName,
                    durationMinutes: max(1, Int(duration / 60)),
                    isQualifying: playbackEngine.accumulator?.hasQualified ?? false
                )
            }
        }
        .alert("Playback Issue", isPresented: Binding(
            get: { playbackEngine.playbackError != nil },
            set: { if !$0 { playbackEngine.playbackError = nil } }
        )) {
            Button("OK", role: .cancel) {
                playbackEngine.playbackError = nil
            }
        } message: {
            Text(playbackEngine.playbackError ?? "Unknown playback issue occurred.")
        }
        .fullScreenCover(isPresented: $isFullScreenVideoPresented) {
            FullScreenVideoPlayerViewController(player: playbackEngine.player) {
                isFullScreenVideoPresented = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: playbackEngine.hasCompletedCurrentSession) { _, completed in
            if completed {
                HapticService.shared.success()
                isShowingCompletionSheet = true
            }
        }
    }
    
    // MARK: - Luminous Custom Scrubber
    private var luminousScrubber: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let progress = duration > 0 ? (displayCurrentTime / duration) : 0.0
                let thumbX = totalWidth * CGFloat(progress)
                
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(CosmosTheme.spaceCardBorder)
                        .frame(height: isScrubbing ? 8 : 6)
                    
                    // Progress Track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [CosmosTheme.cosmicPurple, CosmosTheme.starlightGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, thumbX), height: isScrubbing ? 8 : 6)
                    
                    // Luminous Thumb Dot
                    Circle()
                        .fill(CosmosTheme.starlightGold)
                        .frame(width: isScrubbing ? 18 : 12, height: isScrubbing ? 18 : 12)
                        .shadow(color: CosmosTheme.starlightGold.opacity(0.8), radius: isScrubbing ? 8 : 4)
                        .offset(x: max(0, min(totalWidth - (isScrubbing ? 18 : 12), thumbX - (isScrubbing ? 9 : 6))))
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isScrubbing {
                                isScrubbing = true
                                HapticService.shared.selection()
                            }
                            let ratio = max(0.0, min(1.0, value.location.x / totalWidth))
                            let newTime = ratio * duration
                            if abs(newTime - scrubbedTime) > 5 {
                                HapticService.shared.soft()
                            }
                            scrubbedTime = newTime
                        }
                        .onEnded { value in
                            let ratio = max(0.0, min(1.0, value.location.x / totalWidth))
                            let target = ratio * duration
                            playbackEngine.seek(to: target)
                            HapticService.shared.medium()
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 24)
            
            HStack {
                Text(formatTime(displayCurrentTime))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(max(0, duration - displayCurrentTime)))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(CosmosTheme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 28)
    }
    
    private var planetStyleForTrack: PlanetStyle {
        guard let name = track?.courseName?.lowercased() else { return .purpleRinged }
        if name.contains("health") || name.contains("anxiety") || name.contains("stress") { return .auroraTeal }
        if name.contains("happiness") || name.contains("self-esteem") || name.contains("relationships") { return .solarCoral }
        if name.contains("work") || name.contains("focus") || name.contains("productivity") { return .electricBlue }
        if name.contains("sleep") || name.contains("night") || name.contains("unwind") { return .crescentMoon }
        if name.contains("brave") || name.contains("grief") || name.contains("anger") { return .brave }
        if name.contains("student") { return .deepLavender }
        if name.contains("pro") { return .pro }
        if name.contains("sport") { return .sport }
        return .purpleRinged
    }
    
    private func toggleFavorite() {
        guard let track = track else { return }
        if let existing = favorites.first(where: { $0.sessionStableId == track.id }) {
            modelContext.delete(existing)
        } else {
            let fav = FavoriteItem(
                sessionStableId: track.id,
                title: track.title,
                relativePath: track.relativePath
            )
            modelContext.insert(fav)
        }
        try? modelContext.save()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

/// Isolated breathing visualizer subview that contains its own animation state,
/// preventing the parent MeditationPlayerView from continually invalidating its entire body.
private struct CelestialBreathingAuraView: View {
    let style: PlanetStyle
    let ambientColor: Color
    let isPlaying: Bool
    
    @State private var isBreathing = false
    
    var body: some View {
        ZStack {
            if isPlaying {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ambientColor.opacity(0.40), ambientColor.opacity(0.0)],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(isBreathing ? 1.18 : 1.0)
                    .opacity(isBreathing ? 1.0 : 0.6)
                    .blur(radius: 12)
            }
            
            CelestialPlanetView(
                style: style,
                size: 215,
                hasRings: true,
                isAnimated: isPlaying
            )
            .scaleEffect(isPlaying && isBreathing ? 1.03 : 1.0)
            .padding(.vertical, 16)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}
