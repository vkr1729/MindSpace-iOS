import Foundation
import MediaPlayer

#if os(iOS)
import UIKit
#endif

/// Coordinates Lock Screen & Control Center controls and metadata display via MediaPlayer framework.
@MainActor
public final class NowPlayingCoordinator: Sendable {
    public static let shared = NowPlayingCoordinator()
    
    public var onPlayCommand: (() -> Void)?
    public var onPauseCommand: (() -> Void)?
    public var onTogglePlayPauseCommand: (() -> Void)?
    public var onSkipForwardCommand: ((Double) -> Void)?
    public var onSkipBackwardCommand: ((Double) -> Void)?
    public var onSeekCommand: ((Double) -> Void)?
    
    private var isRegistered = false
    
    public init() {
        setupRemoteCommands()
    }
    
    public func setupRemoteCommands() {
        #if os(iOS)
        guard !isRegistered else { return }
        isRegistered = true
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove existing targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        
        // Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onPlayCommand?() }
            return .success
        }

        // Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onPauseCommand?() }
            return .success
        }

        // Toggle Play/Pause (Headphones / Control Center)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onTogglePlayPauseCommand?() }
            return .success
        }

        // Skip Forward 15s
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15.0
            Task { @MainActor [weak self] in self?.onSkipForwardCommand?(interval) }
            return .success
        }

        // Skip Backward 15s
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15.0
            Task { @MainActor [weak self] in self?.onSkipBackwardCommand?(interval) }
            return .success
        }

        // Scrubber / Change Playback Position
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor [weak self] in self?.onSeekCommand?(posEvent.positionTime) }
                return .success
            }
            return .commandFailed
        }
        
        // Explicitly disable track and playlist skip commands to prioritize 15s skip buttons on lock screen
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
        commandCenter.dislikeCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
        commandCenter.changeRepeatModeCommand.isEnabled = false
        commandCenter.changeShuffleModeCommand.isEnabled = false
        #endif
    }
    
    public func updateNowPlaying(
        title: String,
        artist: String = "MindSpace",
        albumTitle: String? = nil,
        duration: Double,
        currentTime: Double,
        playbackRate: Float
    ) {
        #if os(iOS)
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlaybackDuration: max(1.0, duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0.0, currentTime),
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        
        if let albumTitle = albumTitle, !albumTitle.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        
        // Attach artwork if available. App icons are not image assets, so
        // UIImage(named:) always returns nil for them — go straight to SF.
        if let artworkImage = UIImage(systemName: "sparkles") {
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in
                artworkImage
            }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = (playbackRate > 0 ? .playing : .paused)
        }
        #endif
    }
    
    public func clearNowPlaying() {
        #if os(iOS)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
        #endif
    }

    public func unregisterRemoteCommands() {
        #if os(iOS)
        UIApplication.shared.endReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        isRegistered = false
        #endif
    }
}
