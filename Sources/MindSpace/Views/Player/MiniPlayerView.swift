import SwiftUI

/// Floating mini-player strip docked above the bottom tab bar with glassmorphic depth & tactile controls.
public struct MiniPlayerView: View {
    @ObservedObject private var playbackEngine = PlaybackEngine.shared
    
    public init() {}
    
    private var track: PlayableTrack? {
        playbackEngine.currentTrack
    }
    
    private var isPlaying: Bool {
        playbackEngine.state == .playing
    }
    
    private var progress: Double {
        guard playbackEngine.duration > 0 else { return 0 }
        return min(1.0, playbackEngine.currentTime / playbackEngine.duration)
    }
    
    private var ambientColor: Color {
        CosmosTheme.ambientColor(for: track?.courseName ?? "MindSpace")
    }
    
    public var body: some View {
        if playbackEngine.isMiniPlayerVisible, let track = track {
            HStack(spacing: 12) {
                // Small Planet Art with Ambient Pulse
                ZStack {
                    if isPlaying {
                        Circle()
                            .fill(ambientColor.opacity(0.35))
                            .frame(width: 44, height: 44)
                            .blur(radius: 6)
                    }
                    CelestialPlanetView(style: .purpleRinged, size: 36, hasRings: false)
                        .frame(width: 38, height: 38)
                }

                // Track Title & Course
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(CosmosTheme.textPrimary)
                        .lineLimit(1)

                    Text(track.courseName ?? "MindSpace • 100% Offline")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(CosmosTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Play / Pause Button
                Button(action: {
                    HapticService.shared.medium()
                    playbackEngine.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(CosmosTheme.cosmicPurple.opacity(0.2))
                            .frame(width: 38, height: 38)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(CosmosTheme.cosmicPurple)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                // Close Mini-Player Button
                Button(action: {
                    HapticService.shared.light()
                    playbackEngine.stop()
                    playbackEngine.isMiniPlayerVisible = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CosmosTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(CosmosTheme.spacePill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close mini player")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticService.shared.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    playbackEngine.isFullPlayerPresented = true
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    CosmosTheme.spaceCard
                    LinearGradient(
                        colors: [ambientColor.opacity(0.12), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                // Bottom Progress Line with Starlight Gradient
                VStack {
                    Spacer()
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [CosmosTheme.cosmicPurple, CosmosTheme.starlightGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * CGFloat(progress), height: 2.5)
                    }
                    .frame(height: 2.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
