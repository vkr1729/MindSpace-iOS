import SwiftUI

/// Compact player with separate, correctly exposed open/play/close actions.
public struct MiniPlayerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        MindSpaceTheme.accent(for: track?.courseName ?? "MindSpace")
    }
    
    public var body: some View {
        if playbackEngine.isMiniPlayerVisible, let track = track {
            HStack(spacing: 8) {
                Button {
                    HapticService.shared.light()
                    if reduceMotion {
                        playbackEngine.isFullPlayerPresented = true
                    } else {
                        withAnimation(.easeOut(duration: 0.20)) {
                            playbackEngine.isFullPlayerPresented = true
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        MindSpaceCourseBadge(name: track.courseName ?? track.title, size: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MindSpaceTheme.textPrimary)
                                .lineLimit(1)

                            Text("\(track.courseName ?? "MindSpace") · \(playbackEngine.isStreaming ? "Streaming" : "Offline")")
                                .font(.caption)
                                .foregroundStyle(MindSpaceTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open player for \(track.title)")
                .accessibilityIdentifier("miniPlayer.open")

                Button {
                    HapticService.shared.medium()
                    playbackEngine.togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(MindSpaceTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(MindSpaceTheme.accent.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.mindSpacePressable)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .accessibilityIdentifier("miniPlayer.playPause")

                Button {
                    HapticService.shared.light()
                    playbackEngine.stop()
                    playbackEngine.isMiniPlayerVisible = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MindSpaceTheme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.mindSpacePressable)
                .accessibilityLabel("Close mini player")
                .accessibilityIdentifier("miniPlayer.close")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(MindSpaceTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(ambientColor)
                        .frame(width: proxy.size.width * CGFloat(progress), height: 3)
                }
                .frame(height: 3)
                .clipShape(Capsule())
                .accessibilityHidden(true)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MindSpaceTheme.divider, lineWidth: 1)
                    .accessibilityHidden(true)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
