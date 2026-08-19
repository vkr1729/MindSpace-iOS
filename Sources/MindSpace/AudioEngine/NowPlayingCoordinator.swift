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
    
    public init() {
        setupRemoteCommands()
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
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: playbackRate
        ]
        
        if let albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }
    
    public func clearNowPlaying() {
        #if os(iOS)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #endif
    }
    
    private func setupRemoteCommands() {
        #if os(iOS)
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlayCommand?()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPauseCommand?()
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onTogglePlayPauseCommand?()
            return .success
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                self?.onSkipForwardCommand?(skipEvent.interval)
            } else {
                self?.onSkipForwardCommand?(15.0)
            }
            return .success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            if let skipEvent = event as? MPSkipIntervalCommandEvent {
                self?.onSkipBackwardCommand?(skipEvent.interval)
            } else {
                self?.onSkipBackwardCommand?(15.0)
            }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.onSeekCommand?(posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
        #endif
    }
}
