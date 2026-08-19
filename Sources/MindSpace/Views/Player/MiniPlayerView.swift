import SwiftUI

/// Floating mini-player strip docked above the bottom tab bar.
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
    
    public var body: some View {
        if playbackEngine.isMiniPlayerVisible, let track = track {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    playbackEngine.isFullPlayerPresented = true
                }
            }) {
                HStack(spacing: 12) {
                    // Small Planet Art
                    CelestialPlanetView(style: .purpleRinged, size: 36, hasRings: false)
                        .frame(width: 38, height: 38)
                    
                    // Track Title & Course
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(track.courseName ?? "MindSpace")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play / Pause Button
                    Button(action: {
                        playbackEngine.togglePlayPause()
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(CosmosTheme.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    
                    // Close Mini-Player Button
                    Button(action: {
                        playbackEngine.stop()
                        playbackEngine.isMiniPlayerVisible = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(CosmosTheme.textSecondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(CosmosTheme.spaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    // Bottom Progress Line
                    VStack {
                        Spacer()
                        GeometryReader { proxy in
                            Rectangle()
                                .fill(CosmosTheme.cosmicPurple)
                                .frame(width: proxy.size.width * CGFloat(progress), height: 2)
                        }
                        .frame(height: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(CosmosTheme.spaceCardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
