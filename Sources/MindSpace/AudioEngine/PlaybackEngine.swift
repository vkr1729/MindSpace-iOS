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

public enum PlaybackPhase: String, Sendable, Equatable {
    case video = "video"
    case audio = "audio"
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
    public let videoDuration: Double?
    public let contentType: String // "meditation", "sleep", "video", "sos", "sensitive"
    
    public init(
        id: String,
        title: String,
        courseName: String? = nil,
        relativePath: String,
        duration: Double,
        videoAttachmentPath: String? = nil,
        dayNumber: Int? = nil,
        videoDuration: Double? = nil,
        contentType: String = "meditation"
    ) {
        self.id = id
        self.title = title
        self.courseName = courseName
        self.relativePath = relativePath
        self.duration = duration
        self.videoAttachmentPath = videoAttachmentPath
        self.dayNumber = dayNumber
        self.videoDuration = videoDuration
        self.contentType = contentType
    }
}

public struct PlaybackCompletionInfo: Sendable, Equatable {
    public let track: PlayableTrack
    public let actualMinutes: Int
    public let isQualifying: Bool
    public let completionId: UUID
    
    public init(track: PlayableTrack, actualMinutes: Int, isQualifying: Bool, completionId: UUID) {
        self.track = track
        self.actualMinutes = actualMinutes
        self.isQualifying = isQualifying
        self.completionId = completionId
    }
}

/// Central audio and video playback engine for MindSpace.
@MainActor
public final class PlaybackEngine: ObservableObject {
    public static let shared = PlaybackEngine()
    
    // MARK: - Published State
    @Published public private(set) var state: PlaybackState = .idle
    @Published public private(set) var currentTrack: PlayableTrack?
    @Published public private(set) var currentPhase: PlaybackPhase = .audio
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
    @Published public var playbackError: String?
    @Published public var lastCompletionInfo: PlaybackCompletionInfo?
    @Published public private(set) var isStreaming: Bool = false
    
    // MARK: - Internal AVFoundation & Components
    public var player: AVPlayer?
    public var accumulator: ListeningAccumulator?
    
    private var timeObserverToken: Any?
    private var playerItemObserverTokens: [NSObjectProtocol] = []
    private var sleepTimerTask: Task<Void, Never>?
    private var wasPlayingBeforeInterruption = false
    private var lastSavedResumePosition: Double = 0.0
    private var hasFinalizedCurrentSession = false
    
    // MARK: - Persistence Callbacks
    public var onSessionCompleted: ((PlayableTrack, Double, Bool, UUID) -> Void)?
    public var onSaveResume: ((PlayableTrack, Double, Double) -> Void)? // (track, position, accumulatedListenedSeconds)
    public var onClearResume: ((String) -> Void)?
    
    public init() {
        setupAudioSessionCallbacks()
        setupNowPlayingCallbacks()
    }
    
    deinit {
        // Observers are cleaned up during stop() and track switches.
    }
    
    // MARK: - Playback Commands
    
    public func loadAndPlay(
        track: PlayableTrack,
        startPosition: Double = 0.0,
        accumulatedListenedSeconds: Double = 0.0,
        startInAudioPhase: Bool = false
    ) {
        playbackError = nil
        
        // 1. If previous track was running and has not finalized, evaluate completion or save resume
        if let previousTrack = currentTrack, previousTrack.id != track.id {
            if let acc = accumulator, acc.hasQualified && !hasFinalizedCurrentSession {
                finalizeCurrentSession(trigger: "track_switch")
            } else if !hasFinalizedCurrentSession && currentTime > 3.0 {
                saveCurrentResumePosition()
            }
        }
        
        // 2. Stop previous player and clean up before activating audio session
        stop(preserveMiniPlayer: true)
        
        // 3. Activate audio session for the new playback
        AudioSessionManager.shared.activateSession()
        NowPlayingCoordinator.shared.setupRemoteCommands()
        
        self.currentTrack = track
        self.hasCompletedCurrentSession = false
        self.hasFinalizedCurrentSession = false
        self.isMiniPlayerVisible = true
        
        // 4. Check if there is an attached day-video to play first
        if let videoRel = track.videoAttachmentPath,
           !startInAudioPhase && startPosition == 0.0 {
            if let videoURL = LibraryPathResolver.shared.resolveURL(for: videoRel) {
                // Play local video
                self.isStreaming = false
                playVideoItem(playerItem: AVPlayerItem(url: videoURL), track: track)
                return
            } else if let (streamAsset, _) = LibraryPathResolver.shared.resolveRemoteStreamAsset(for: videoRel) {
                // Stream video from private GitHub
                self.isStreaming = true
                playVideoItem(playerItem: AVPlayerItem(asset: streamAsset), track: track)
                return
            }
        }
        
        // 5. Play audio session
        startAudioPhase(track: track, startPosition: startPosition, accumulatedSeconds: accumulatedListenedSeconds)
    }
    
    private func playVideoItem(playerItem: AVPlayerItem, track: PlayableTrack) {
        self.currentPhase = .video
        self.duration = track.videoDuration ?? 0.0
        self.currentTime = 0.0
        self.lastSavedResumePosition = 0.0
        self.state = .loading
        
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        self.player = avPlayer
        
        setupTimeObserver()
        setupItemObservers(for: playerItem)
        
        avPlayer.playImmediately(atRate: speed.rawValue)
        self.state = .playing
        updateNowPlayingCenter()
    }
    
    private func startAudioPhase(track: PlayableTrack, startPosition: Double, accumulatedSeconds: Double) {
        self.currentPhase = .audio
        self.duration = track.duration
        self.currentTime = startPosition
        self.lastSavedResumePosition = startPosition
        self.state = .loading
        
        let acc = ListeningAccumulator(duration: track.duration, initialAccumulatedSeconds: accumulatedSeconds)
        self.accumulator = acc
        
        // 1. Priority 1: Check Local File (0ms latency, true offline)
        if let localURL = LibraryPathResolver.shared.resolveURL(for: track.relativePath) {
            self.isStreaming = false
            let playerItem = AVPlayerItem(url: localURL)
            setupAndStartPlayer(playerItem: playerItem, startPosition: startPosition)
            return
        }
        
        // 2. Priority 2: Fallback to On-Demand Streaming from Private GitHub
        if let (streamAsset, _) = LibraryPathResolver.shared.resolveRemoteStreamAsset(for: track.relativePath) {
            self.isStreaming = true
            let playerItem = AVPlayerItem(asset: streamAsset)
            setupAndStartPlayer(playerItem: playerItem, startPosition: startPosition)
            return
        }
        
        // 3. Fallback: Not downloaded & PAT not configured
        self.isStreaming = false
        self.state = .idle
        if !GitHubSyncService.shared.isConfigured {
            self.playbackError = "Track '\(track.title)' is not downloaded. Configure GitHub Token in Settings to stream online or download for offline play."
        } else {
            self.playbackError = "Unable to play track '\(track.title)'. Please check your internet connection or download it for offline play."
        }
    }
    
    private func setupAndStartPlayer(playerItem: AVPlayerItem, startPosition: Double) {
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        self.player = avPlayer
        
        setupTimeObserver()
        setupItemObservers(for: playerItem)
        
        if startPosition > 0.0 {
            let cmTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        avPlayer.playImmediately(atRate: speed.rawValue)
        self.state = .playing
        updateNowPlayingCenter()
    }
    
    public func skipVideoToAudio() {
        guard currentPhase == .video, let track = currentTrack else { return }
        cleanupObservers()
        player?.pause()
        player = nil
        startAudioPhase(track: track, startPosition: 0.0, accumulatedSeconds: 0.0)
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
            accumulator?.reset()
            hasCompletedCurrentSession = false
            hasFinalizedCurrentSession = false
        }
        
        player.playImmediately(atRate: speed.rawValue)
        state = .playing
        updateNowPlayingCenter()
    }
    
    public func pause() {
        guard let player = player else { return }
        player.pause()
        state = .paused
        accumulator?.tick(currentTime: currentTime, isPlaying: false, speed: Double(speed.rawValue))
        saveCurrentResumePosition()
        updateNowPlayingCenter()
    }
    
    public func stop(preserveMiniPlayer: Bool = false) {
        cleanupObservers()
        
        if currentTrack != nil && !hasFinalizedCurrentSession && currentPhase == .audio {
            if let acc = accumulator, acc.hasQualified {
                finalizeCurrentSession(trigger: "stop")
            } else if currentTime > 3.0 {
                saveCurrentResumePosition()
            }
        }
        
        player?.pause()
        player = nil
        state = .idle
        currentTime = 0.0
        isStreaming = false
        if !preserveMiniPlayer {
            isMiniPlayerVisible = false
        }
        NowPlayingCoordinator.shared.clearNowPlaying()
        AudioSessionManager.shared.deactivateSession()
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
    
    public func saveCurrentResumePosition() {
        guard let track = currentTrack, currentTime > 0.0, !hasFinalizedCurrentSession, currentPhase == .audio else { return }
        lastSavedResumePosition = currentTime
        let accSeconds = accumulator?.accumulatedSeconds ?? 0.0
        onSaveResume?(track, currentTime, accSeconds)
    }
    
    // MARK: - Time & Item Observers
    
    private func setupTimeObserver() {
        guard let player = player else { return }
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let secs = time.seconds
                if !secs.isNaN && !secs.isInfinite {
                    self.currentTime = secs
                    let isPlaying = (self.state == .playing)
                    if self.currentPhase == .audio {
                        self.accumulator?.tick(currentTime: secs, isPlaying: isPlaying, speed: Double(self.speed.rawValue))
                        if isPlaying && abs(secs - self.lastSavedResumePosition) >= 10.0 {
                            self.saveCurrentResumePosition()
                        }
                    }
                }
            }
        }
    }
    
    private func setupItemObservers(for item: AVPlayerItem) {
        removePlayerItemObservers()
        
        let endToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleTrackEnded()
            }
        }
        playerItemObserverTokens.append(endToken)
        
        let failToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.state = .idle
                let err = (notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription ?? "Corrupt or unreadable media stream"
                self.playbackError = "Playback error: \(err). Please rescan library in Settings."
            }
        }
        playerItemObserverTokens.append(failToken)
    }
    
    private func removePlayerItemObservers() {
        for token in playerItemObserverTokens {
            NotificationCenter.default.removeObserver(token)
        }
        playerItemObserverTokens.removeAll()
    }
    
    public func cleanupObservers() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        removePlayerItemObservers()
    }
    
    private func handleTrackEnded() {
        if currentPhase == .video, let track = currentTrack, track.videoAttachmentPath != nil && track.relativePath != track.videoAttachmentPath {
            // Attached day video completed -> smoothly transition to associated audio session
            cleanupObservers()
            player?.pause()
            player = nil
            startAudioPhase(track: track, startPosition: 0.0, accumulatedSeconds: 0.0)
            return
        }
        
        state = .completed
        finalizeCurrentSession(trigger: "track_ended")
        updateNowPlayingCenter()
    }
    
    private func finalizeCurrentSession(trigger: String) {
        guard let track = currentTrack, !hasFinalizedCurrentSession else { return }
        hasFinalizedCurrentSession = true
        
        let acc = accumulator
        let isQualifying = acc?.hasQualified ?? false
        let listenedSeconds = acc?.actualPlayedSeconds ?? (acc?.accumulatedSeconds ?? currentTime)
        let actualMinutes = max(1, Int(round(listenedSeconds / 60.0)))
        let completionId = UUID()
        
        lastCompletionInfo = PlaybackCompletionInfo(
            track: track,
            actualMinutes: actualMinutes,
            isQualifying: isQualifying,
            completionId: completionId
        )
        
        hasCompletedCurrentSession = true
        onSessionCompleted?(track, listenedSeconds, isQualifying, completionId)
        
        if isQualifying {
            onClearResume?(track.id)
        }
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
        let displayTitle = (currentPhase == .video) ? "\(track.title) (Video)" : track.title
        NowPlayingCoordinator.shared.updateNowPlaying(
            title: displayTitle,
            albumTitle: track.courseName,
            duration: duration > 0 ? duration : track.duration,
            currentTime: currentTime,
            playbackRate: rate
        )
    }
}
