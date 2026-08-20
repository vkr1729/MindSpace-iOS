import Foundation
import AVFoundation
import Combine
import SwiftUI

public enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case readyToPlay
    case playing
    case paused
    case interrupted
    case completed
}

public enum PlaybackSpeed: Float, CaseIterable, Sendable {
    case slow = 0.75
    case normal = 1.0
    case fast = 1.25
    
    public var label: String {
        switch self {
        case .slow: return "0.75x"
        case .normal: return "1.0x"
        case .fast: return "1.25x"
        }
    }
}

public struct PlayableTrack: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let courseName: String?
    public let relativePath: String
    public let duration: Double
    public let videoAttachmentPath: String?
    public let dayNumber: Int?
    
    public init(
        id: String,
        title: String,
        courseName: String? = nil,
        relativePath: String,
        duration: Double,
        videoAttachmentPath: String? = nil,
        dayNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.courseName = courseName
        self.relativePath = relativePath
        self.duration = duration
        self.videoAttachmentPath = videoAttachmentPath
        self.dayNumber = dayNumber
    }
}

/// Central audio and video playback engine for MindSpace.
@MainActor
public final class PlaybackEngine: ObservableObject {
    public static let shared = PlaybackEngine()
    
    // MARK: - Published State
    @Published public private(set) var state: PlaybackState = .idle
    @Published public private(set) var currentTrack: PlayableTrack?
    @Published public private(set) var currentTime: Double = 0.0
    @Published public private(set) var duration: Double = 0.0
    @Published public var speed: PlaybackSpeed = .normal {
        didSet {
            if state == .playing {
                player?.rate = speed.rawValue
            }
        }
    }
    @Published public var sleepTimerMinutesRemaining: Int?
    @Published public var isMiniPlayerVisible: Bool = false
    @Published public var isFullPlayerPresented: Bool = false
    @Published public var hasCompletedCurrentSession: Bool = false
    
    // MARK: - Internal AVFoundation & Components
    public var player: AVPlayer?
    public var accumulator: ListeningAccumulator?
    
    private var timeObserverToken: Any?
    private var sleepTimerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var wasPlayingBeforeInterruption = false
    
    public var onSessionCompleted: ((PlayableTrack, Double) -> Void)?
    
    public init() {
        setupAudioSessionCallbacks()
        setupNowPlayingCallbacks()
    }
    
    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }
    
    // MARK: - Playback Commands
    
    public func loadAndPlay(track: PlayableTrack, startPosition: Double = 0.0) {
        AudioSessionManager.shared.activateSession()
        NowPlayingCoordinator.shared.setupRemoteCommands()
        
        stop()
        
        self.currentTrack = track
        self.duration = track.duration
        self.currentTime = startPosition
        self.state = .loading
        self.isMiniPlayerVisible = true
        self.hasCompletedCurrentSession = false
        
        let acc = ListeningAccumulator(duration: track.duration)
        self.accumulator = acc
        
        guard let url = LibraryPathResolver.shared.resolveURL(for: track.relativePath) else {
            self.state = .idle
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        self.player = avPlayer
        
        setupTimeObserver()
        setupEndObserver(for: playerItem)
        
        if startPosition > 0.0 {
            let cmTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        avPlayer.playImmediately(atRate: speed.rawValue)
        self.state = .playing
        
        updateNowPlayingCenter()
    }
    
    public func togglePlayPause() {
        if state == .playing {
            pause()
        } else {
            play()
        }
    }
    
    public func play() {
        guard let player = player else { return }
        AudioSessionManager.shared.activateSession()
        
        if state == .completed {
            seek(to: 0.0)
        }
        
        player.playImmediately(atRate: speed.rawValue)
        state = .playing
        updateNowPlayingCenter()
    }
    
    public func pause() {
        guard let player = player else { return }
        player.pause()
        state = .paused
        accumulator?.tick(currentTime: currentTime, isPlaying: false)
        updateNowPlayingCenter()
    }
    
    public func stop() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        state = .idle
        currentTime = 0.0
        NowPlayingCoordinator.shared.clearNowPlaying()
    }
    
    public func seek(to targetSeconds: Double) {
        let effectiveDuration = duration > 0 ? duration : (currentTrack?.duration ?? 0.0)
        let clamped = max(0.0, min(effectiveDuration, targetSeconds))
        self.currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        if state == .completed && clamped < max(0, effectiveDuration - 1.0) {
            state = .paused
        }
        updateNowPlayingCenter()
    }
    
    public func skipForward(_ seconds: Double = 15.0) {
        seek(to: currentTime + seconds)
    }
    
    public func skipBackward(_ seconds: Double = 15.0) {
        seek(to: currentTime - seconds)
    }
    
    public func setSpeed(_ newSpeed: PlaybackSpeed) {
        self.speed = newSpeed
        if state == .playing {
            player?.rate = newSpeed.rawValue
        }
        updateNowPlayingCenter()
    }
    
    public func setSleepTimer(minutes: Int?) {
        sleepTimerTask?.cancel()
        sleepTimerMinutesRemaining = minutes
        
        guard let mins = minutes, mins > 0 else { return }
        
        sleepTimerTask = Task { [weak self] in
            var remaining = mins
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
                self?.sleepTimerMinutesRemaining = remaining
            }
            self?.pause()
            self?.sleepTimerMinutesRemaining = nil
        }
    }
    
    // MARK: - Time Observers
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600) // 10Hz observer for UI
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let secs = time.seconds
            if !secs.isNaN && !secs.isInfinite {
                self.currentTime = secs
                let isPlaying = (self.state == .playing)
                self.accumulator?.tick(currentTime: secs, isPlaying: isPlaying)
                // Note: We do NOT call updateNowPlayingCenter() on every 100ms tick to avoid XPC rate-limiting.
                // MPNowPlayingInfo elapsed time is automatically updated in real-time by iOS using playbackRate.
            }
        }
    }
    
    private func setupEndObserver(for item: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackEnded()
        }
    }
    
    private func handleTrackEnded() {
        state = .completed
        hasCompletedCurrentSession = true
        if let track = currentTrack {
            let listenedSeconds = accumulator?.accumulatedSeconds ?? currentTime
            onSessionCompleted?(track, listenedSeconds)
        }
        updateNowPlayingCenter()
    }
    
    // MARK: - Callbacks Setup
    
    private func setupAudioSessionCallbacks() {
        let asm = AudioSessionManager.shared
        asm.onInterruptionBegan = { [weak self] in
            guard let self = self else { return }
            self.wasPlayingBeforeInterruption = (self.state == .playing)
            self.pause()
            self.state = .interrupted
        }
        
        asm.onInterruptionEndedShouldResume = { [weak self] in
            guard let self = self else { return }
            if self.wasPlayingBeforeInterruption {
                self.play()
            }
        }
        
        asm.onHeadphonesDisconnected = { [weak self] in
            self?.pause()
        }
    }
    
    private func setupNowPlayingCallbacks() {
        let npc = NowPlayingCoordinator.shared
        npc.onPlayCommand = { [weak self] in self?.play() }
        npc.onPauseCommand = { [weak self] in self?.pause() }
        npc.onTogglePlayPauseCommand = { [weak self] in self?.togglePlayPause() }
        npc.onSkipForwardCommand = { [weak self] interval in self?.skipForward(interval) }
        npc.onSkipBackwardCommand = { [weak self] interval in self?.skipBackward(interval) }
        npc.onSeekCommand = { [weak self] pos in self?.seek(to: pos) }
    }
    
    private func updateNowPlayingCenter() {
        guard let track = currentTrack else { return }
        let rate: Float = (state == .playing) ? speed.rawValue : 0.0
        NowPlayingCoordinator.shared.updateNowPlaying(
            title: track.title,
            albumTitle: track.courseName,
            duration: duration > 0 ? duration : track.duration,
            currentTime: currentTime,
            playbackRate: rate
        )
    }
}
