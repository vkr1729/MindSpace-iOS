import SwiftUI

/// Screen 4: Minimalist Meditation Player (Canonical Blueprint)
/// Reference: Mock Screen Codex.png
public struct MeditationPlayerView: View {
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingCompletionSheet = false
    @State private var isScrubbing = false
    @State private var scrubbedTime: Double = 0.0
    
    public init() {}
    
    private var track: PlayableTrack? {
        playbackEngine.currentTrack
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
    
    public var body: some View {
        ZStack {
            CosmosTheme.spaceBackground.ignoresSafeArea()
            StarsBackgroundView()
            
            VStack(spacing: 24) {
                // MARK: - Navigation Bar
                HStack {
                    Button(action: {
                        playbackEngine.isFullPlayerPresented = false
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(CosmosTheme.spaceCard)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(track?.title ?? "Meditation")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(CosmosTheme.auroraTeal)
                                .frame(width: 6, height: 6)
                            Text("Offline")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: {
                            // Toggle favorite
                        }) {
                            Label("Favorite", systemImage: "star")
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
                
                Spacer()
                
                // MARK: - Central Visual Anchor (3D Planet or Video)
                if let videoRel = track?.videoAttachmentPath,
                   let _ = LibraryPathResolver.shared.resolveURL(for: videoRel) {
                    VideoPlayerView(player: playbackEngine.player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .shadow(color: CosmosTheme.cosmicPurple.opacity(0.3), radius: 16)
                } else {
                    CelestialPlanetView(
                        style: planetStyleForTrack,
                        size: 210,
                        hasRings: true,
                        isAnimated: isPlaying
                    )
                    .padding(.vertical, 16)
                }
                
                Spacer()
                
                // MARK: - Digital Time Readout
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text(formatTime(displayCurrentTime))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                        
                        Text("/ of \(formatTime(duration))")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .offset(y: 4)
                    }
                    
                    // MARK: - Scrubber Bar
                    VStack(spacing: 6) {
                        GeometryReader { geometry in
                            let totalWidth = geometry.size.width
                            let progress = duration > 0 ? (displayCurrentTime / duration) : 0.0
                            
                            ZStack(alignment: .leading) {
                                // Background Track
                                Capsule()
                                    .fill(CosmosTheme.spaceCardBorder)
                                    .frame(height: 6)
                                
                                // Progress Track
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [CosmosTheme.cosmicPurple, CosmosTheme.starlightGold],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: totalWidth * CGFloat(progress), height: 6)
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isScrubbing = true
                                        let ratio = max(0.0, min(1.0, value.location.x / totalWidth))
                                        scrubbedTime = ratio * duration
                                    }
                                    .onEnded { value in
                                        let ratio = max(0.0, min(1.0, value.location.x / totalWidth))
                                        let target = ratio * duration
                                        playbackEngine.seek(to: target)
                                        isScrubbing = false
                                    }
                            )
                        }
                        .frame(height: 14)
                        
                        HStack {
                            Text(formatTime(displayCurrentTime))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                            Spacer()
                            Text("-\(formatTime(max(0, duration - displayCurrentTime)))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(CosmosTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 28)
                }
                
                // MARK: - Controls (Skip ±15s & Glowing Play/Pause)
                HStack(spacing: 36) {
                    // Skip Backward 15s
                    Button(action: {
                        playbackEngine.skipBackward(15)
                    }) {
                        ZStack {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(CosmosTheme.textPrimary)
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    
                    // Large Play / Pause Button
                    Button(action: {
                        playbackEngine.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(CosmosTheme.cosmicPurple)
                                .frame(width: 76, height: 76)
                                .shadow(color: CosmosTheme.cosmicPurple.opacity(0.6), radius: 16, x: 0, y: 4)
                            
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Skip Forward 15s
                    Button(action: {
                        playbackEngine.skipForward(15)
                    }) {
                        ZStack {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(CosmosTheme.textPrimary)
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                
                // MARK: - Bottom Pill Controls (Speed & Sleep Timer)
                HStack(spacing: 16) {
                    // Speed Toggle Pill
                    Menu {
                        ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                            Button(action: {
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
                        .padding(.vertical, 10)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                    }
                    
                    // Sleep Timer Pill
                    Menu {
                        Button("Off") { playbackEngine.setSleepTimer(minutes: nil) }
                        Button("5 minutes") { playbackEngine.setSleepTimer(minutes: 5) }
                        Button("10 minutes") { playbackEngine.setSleepTimer(minutes: 10) }
                        Button("15 minutes") { playbackEngine.setSleepTimer(minutes: 15) }
                        Button("30 minutes") { playbackEngine.setSleepTimer(minutes: 30) }
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
                        .padding(.vertical, 10)
                        .background(CosmosTheme.spaceCard)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(playbackEngine.sleepTimerMinutesRemaining != nil ? CosmosTheme.starlightGold.opacity(0.6) : CosmosTheme.spaceCardBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isShowingCompletionSheet) {
            if let track = track {
                CompletionView(
                    sessionTitle: track.title,
                    courseName: track.courseName,
                    durationMinutes: Int(duration / 60)
                )
            }
        }
        .onChange(of: playbackEngine.hasCompletedCurrentSession) { _, completed in
            if completed {
                isShowingCompletionSheet = true
            }
        }
    }
    
    private var planetStyleForTrack: PlanetStyle {
        guard let name = track?.courseName?.lowercased() else { return .purpleRinged }
        if name.contains("health") || name.contains("anxiety") { return .auroraTeal }
        if name.contains("happiness") || name.contains("self-esteem") { return .solarCoral }
        if name.contains("work") || name.contains("focus") { return .electricBlue }
        if name.contains("sleep") { return .crescentMoon }
        return .purpleRinged
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
