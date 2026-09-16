import SwiftUI
import SwiftData

/// Screen 4: Elevated Minimalist Meditation Player with Celestial Breathing Aura & Luminous Scrubber
/// Reference: Mock Screen Codex.png & UI/UX Pro Max Design Intelligence
public struct MeditationPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    
    private var isVideoPhase: Bool {
        playbackEngine.currentPhase == .video
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.5), value: isPlaying)
            
            StarsBackgroundView()
            
            VStack(spacing: 18) {
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
                    .accessibilityLabel("Minimize player")
                    
                    Spacer()
                    
                    VStack(spacing: 3) {
                        Text(track?.title ?? "Meditation")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(playbackEngine.isStreaming ? CosmosTheme.starlightGold : CosmosTheme.auroraTeal)
                                .frame(width: 6, height: 6)
                            Text(playbackEngine.isStreaming ? "✦ Cosmic Stream" : (isVideoPhase ? "Video Lesson • 100% Offline" : "100% Offline"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(playbackEngine.isStreaming ? CosmosTheme.starlightGold : CosmosTheme.textSecondary)
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
                        .accessibilityLabel(isZenMode ? "Exit Zen Mode" : "Enter Zen Mode")
                        
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
                        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer()
                
                // MARK: - Central Visual Anchor (Video Player Layer or Celestial Breathing Aura)
                ZStack {
                    if isVideoPhase {
                        VStack(spacing: 12) {
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
                                .accessibilityLabel("Full screen video")
                            }
                            .padding(.horizontal, 20)
                            
                            // Option to skip video to audio directly
                            if track?.videoAttachmentPath != nil && track?.relativePath != track?.videoAttachmentPath {
                                Button(action: {
                                    HapticService.shared.light()
                                    playbackEngine.skipVideoToAudio()
                                }) {
                                    HStack(spacing: 6) {
                                        Text("Skip to Meditation Audio")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        Image(systemName: "forward.end.fill")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(CosmosTheme.moonLavender)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(CosmosTheme.spaceCard)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                                }
                                .buttonStyle(.cosmicPressable)
                            }
                        }
                    } else {
                        CelestialBreathingAuraView(
                            style: planetStyleForTrack,
                            ambientColor: ambientColor,
                            isPlaying: isPlaying,
                            reduceMotion: reduceMotion
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
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                        Text("/ of \(formatTime(duration))")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                    }
                    
                    // Luminous Touch-Responsive & VoiceOver-Accessible Scrubber
                    luminousScrubber
                }
                .opacity(isZenMode ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isZenMode)
                .padding(.horizontal, 24)
                
                // MARK: - Playback Controls
                HStack(spacing: 36) {
                    // Skip Backward 15s
                    Button(action: {
                        HapticService.shared.medium()
                        playbackEngine.skipBackward(15)
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(CosmosTheme.textPrimary)
                        }
                        .frame(width: 52, height: 52)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.cosmicPressable)
                    .accessibilityLabel("Skip back 15 seconds")
                    
                    // Primary Play/Pause Button
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
                                .shadow(color: CosmosTheme.cosmicPurple.opacity(0.6), radius: 16, x: 0, y: 6)
                            
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .buttonStyle(.cosmicPressable)
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    
                    // Skip Forward 15s
                    Button(action: {
                        HapticService.shared.medium()
                        playbackEngine.skipForward(15)
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(CosmosTheme.textPrimary)
                        }
                        .frame(width: 52, height: 52)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.cosmicPressable)
                    .accessibilityLabel("Skip forward 15 seconds")
                }
                .opacity(isZenMode ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isZenMode)
                .padding(.top, 4)
                
                // MARK: - Speed and Sleep Timer Controls
                HStack(spacing: 12) {
                    // Speed Control Pill
                    Menu {
                        ForEach(PlaybackSpeed.allCases, id: \.self) { spd in
                            Button(action: {
                                HapticService.shared.selection()
                                playbackEngine.setSpeed(spd)
                            }) {
                                HStack {
                                    Text(spd.label)
                                    if playbackEngine.speed == spd {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                .font(.system(size: 13))
                            Text(playbackEngine.speed.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(CosmosTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                    
                    // Sleep Timer Pill
                    Menu {
                        Button("Off") {
                            HapticService.shared.selection()
                            playbackEngine.setSleepTimer(minutes: nil)
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
                            Image(systemName: "timer")
                                .font(.system(size: 13))
                            if let remaining = playbackEngine.sleepTimerMinutesRemaining {
                                Text("\(remaining)m")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(CosmosTheme.starlightGold)
                            } else {
                                Text("Timer")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(CosmosTheme.textPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1))
                    }
                }
                .opacity(isZenMode ? 0.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isZenMode)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $isShowingCompletionSheet) {
            if let comp = playbackEngine.lastCompletionInfo {
                CompletionView(
                    completionId: comp.completionId,
                    sessionTitle: comp.track.title,
                    courseName: comp.track.courseName,
                    durationMinutes: comp.actualMinutes,
                    isQualifying: comp.isQualifying
                )
            } else if let trk = track {
                CompletionView(
                    sessionTitle: trk.title,
                    courseName: trk.courseName,
                    durationMinutes: max(1, Int(round(duration / 60.0))),
                    isQualifying: true
                )
            }
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
    
    // MARK: - Luminous Accessible Scrubber
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
                            scrubbedTime = ratio * duration
                        }
                        .onEnded { value in
                            let ratio = max(0.0, min(1.0, value.location.x / totalWidth))
                            let target = ratio * duration
                            playbackEngine.seek(to: target)
                            isScrubbing = false
                            HapticService.shared.medium()
                        }
                )
            }
            .frame(height: 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(formatTime(displayCurrentTime)) of \(formatTime(duration))")
            .accessibilityAdjustableAction { direction in
                let step: Double = 15.0
                switch direction {
                case .increment:
                    playbackEngine.skipForward(step)
                case .decrement:
                    playbackEngine.skipBackward(step)
                @unknown default:
                    break
                }
            }
        }
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
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(max(0, seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private var planetStyleForTrack: CelestialPlanetStyle {
        let name = track?.courseName?.lowercased() ?? track?.title.lowercased() ?? ""
        if name.contains("basics") { return .purpleRinged }
        if name.contains("anxiety") || name.contains("stress") { return .solarCoral }
        if name.contains("health") || name.contains("pregnancy") { return .auroraTeal }
        if name.contains("focus") || name.contains("work") { return .electricBlue }
        return .deepCosmos
    }
}

/// Serene floating planet visual anchor with breathing aura
private struct CelestialBreathingAuraView: View {
    let style: CelestialPlanetStyle
    let ambientColor: Color
    let isPlaying: Bool
    let reduceMotion: Bool
    
    @State private var breathScale: CGFloat = 1.0
    @State private var auraOpacity: Double = 0.4
    
    var body: some View {
        ZStack {
            // Soft atmospheric radial aura
            if !reduceMotion {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ambientColor.opacity(auraOpacity), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 160
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(breathScale)
            }
            
            // 3D Celestial Planet with Cinematic Alpha & Breathing
            CelestialPlanetView(style: style, size: 160, hasRings: true, isAnimated: isPlaying)
                .shadow(color: ambientColor.opacity(isPlaying ? 0.6 : 0.3), radius: isPlaying ? 30 : 15)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    breathScale = 1.18
                    auraOpacity = 0.75
                }
            }
        }
    }
}
