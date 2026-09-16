import SwiftUI
import SwiftData

/// Focused meditation player with playback state, time, and controls first.
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
        MindSpaceTheme.accent(for: track?.courseName ?? "MindSpace")
    }

    private var isVideoPhase: Bool {
        playbackEngine.currentPhase == .video
    }

    public var body: some View {
        ZStack {
            MindSpaceTheme.background.ignoresSafeArea()

            // Subtle state depth, never a decorative illustration.
            RadialGradient(
                colors: [ambientColor.opacity(isPlaying ? 0.10 : 0.04), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 360
            )
            .ignoresSafeArea()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: isPlaying)
            .accessibilityHidden(true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                // MARK: - Navigation Bar
                HStack {
                    Button(action: {
                        HapticService.shared.light()
                        playbackEngine.isFullPlayerPresented = false
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.bold))
                            .foregroundStyle(MindSpaceTheme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(MindSpaceTheme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                    }
                    .buttonStyle(.mindSpacePressable)
                    .accessibilityLabel("Minimize player")
                    .accessibilityIdentifier("player.minimize")

                    Spacer()

                    VStack(spacing: 3) {
                        Text(track?.title ?? "Meditation")
                            .font(.headline)
                            .foregroundStyle(MindSpaceTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(playbackEngine.isStreaming ? MindSpaceTheme.completion : MindSpaceTheme.success)
                                .frame(width: 6, height: 6)
                            Text(playbackEngine.isStreaming ? "Streaming" : (isVideoPhase ? "Video · Offline" : "Offline"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(playbackEngine.isStreaming ? MindSpaceTheme.warning : MindSpaceTheme.textSecondary)
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
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isZenMode ? MindSpaceTheme.accent : MindSpaceTheme.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(MindSpaceTheme.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                        }
                        .buttonStyle(.mindSpacePressable)
                        .accessibilityLabel(isZenMode ? "Exit Zen Mode" : "Enter Zen Mode")

                        // Favorite Star Button
                        Button(action: {
                            HapticService.shared.medium()
                            toggleFavorite()
                        }) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.body.weight(.bold))
                                .foregroundStyle(isFavorite ? MindSpaceTheme.completion : MindSpaceTheme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(MindSpaceTheme.surface)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                        }
                        .buttonStyle(.mindSpacePressable)
                        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // MARK: - Video or optional breathing cue
                ZStack {
                    if isVideoPhase {
                        VStack(spacing: 12) {
                            ZStack(alignment: .topTrailing) {
                                VideoPlayerView(player: playbackEngine.player)
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .cornerRadius(22)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(MindSpaceTheme.divider, lineWidth: 1)
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
                                        .foregroundColor(MindSpaceTheme.textPrimary)
                                        .padding(8)
                                        .background(MindSpaceTheme.background.opacity(0.8))
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
                                    .foregroundColor(MindSpaceTheme.secondaryAccent)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(MindSpaceTheme.surface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(MindSpaceTheme.divider, lineWidth: 1))
                                }
                                .buttonStyle(.mindSpacePressable)
                            }
                        }
                    } else {
                        FocusBreathingView(
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
                            .foregroundColor(MindSpaceTheme.textPrimary)
                            .monospacedDigit()

                        Text("/ of \(formatTime(duration))")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(MindSpaceTheme.textSecondary)
                    }

                    // Touch- and VoiceOver-accessible scrubber
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
                                .foregroundColor(MindSpaceTheme.textPrimary)
                        }
                        .frame(width: 52, height: 52)
                        .background(MindSpaceTheme.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                    }
                    .buttonStyle(.mindSpacePressable)
                    .accessibilityLabel("Skip back 15 seconds")

                    // Primary Play/Pause Button
                    Button(action: {
                        HapticService.shared.medium()
                        playbackEngine.togglePlayPause()
                    }) {
                        ZStack {
                            Circle()
                                .fill(MindSpaceTheme.accent)
                                .frame(width: 78, height: 78)

                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(MindSpaceTheme.background)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .buttonStyle(.mindSpacePressable)
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    .accessibilityIdentifier("player.playPause")

                    // Skip Forward 15s
                    Button(action: {
                        HapticService.shared.medium()
                        playbackEngine.skipForward(15)
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(MindSpaceTheme.textPrimary)
                        }
                        .frame(width: 52, height: 52)
                        .background(MindSpaceTheme.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(MindSpaceTheme.divider, lineWidth: 1))
                    }
                    .buttonStyle(.mindSpacePressable)
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
                        .foregroundColor(MindSpaceTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MindSpaceTheme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MindSpaceTheme.divider, lineWidth: 1))
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
                                    .foregroundColor(MindSpaceTheme.completion)
                            } else {
                                Text("Timer")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(MindSpaceTheme.textPrimary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MindSpaceTheme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MindSpaceTheme.divider, lineWidth: 1))
                    }
                }
                .opacity(isZenMode ? 0.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isZenMode)

                Spacer(minLength: 24)
                }
            }
        }
        .accessibilityIdentifier("player.full")
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

    // MARK: - Accessible scrubber
    private var luminousScrubber: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let progress = duration > 0 ? (displayCurrentTime / duration) : 0.0
                let thumbX = totalWidth * CGFloat(progress)

                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(MindSpaceTheme.divider)
                        .frame(height: isScrubbing ? 8 : 6)

                    // Progress track
                    Capsule()
                        .fill(MindSpaceTheme.accent)
                        .frame(width: max(6, thumbX), height: isScrubbing ? 8 : 6)

                    // Thumb
                    Circle()
                        .fill(MindSpaceTheme.accent)
                        .frame(width: isScrubbing ? 18 : 12, height: isScrubbing ? 18 : 12)
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

}

/// A functional breathing cue shown only in the audio phase. It communicates
/// playback state without becoming a decorative hero image.
private struct FocusBreathingView: View {
    let ambientColor: Color
    let isPlaying: Bool
    let reduceMotion: Bool

    @State private var breathScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(ambientColor.opacity(0.20), lineWidth: 1)
                    .frame(width: 184, height: 184)
                    .scaleEffect(isPlaying && !reduceMotion ? breathScale : 1)

                Circle()
                    .fill(ambientColor.opacity(0.08))
                    .frame(width: 150, height: 150)

                Image(systemName: isPlaying ? "waveform" : "pause")
                    .font(.title.weight(.light))
                    .foregroundStyle(ambientColor)
                    .accessibilityHidden(true)
            }

            Text(isPlaying ? "Breathe naturally" : "Paused")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MindSpaceTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPlaying ? "Playing. Breathe naturally." : "Playback paused")
        .onAppear {
            if isPlaying && !reduceMotion {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    breathScale = 1.08
                }
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing && !reduceMotion {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    breathScale = 1.08
                }
            } else {
                breathScale = 1
            }
        }
    }
}
