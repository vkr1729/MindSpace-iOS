import XCTest
import Foundation
import MediaPlayer
import AVFoundation
@testable import MindSpace

final class LockScreenPlaybackTests: XCTestCase {
    
    @MainActor
    func testNowPlayingCoordinatorCommandConfiguration() {
        let coordinator = NowPlayingCoordinator.shared
        coordinator.setupRemoteCommands()
        
        var playCalled = false
        var pauseCalled = false
        var toggleCalled = false
        var skipFwdInterval: Double = 0
        var skipBackInterval: Double = 0
        var seekTarget: Double = 0
        
        coordinator.onPlayCommand = { playCalled = true }
        coordinator.onPauseCommand = { pauseCalled = true }
        coordinator.onTogglePlayPauseCommand = { toggleCalled = true }
        coordinator.onSkipForwardCommand = { skipFwdInterval = $0 }
        coordinator.onSkipBackwardCommand = { skipBackInterval = $0 }
        coordinator.onSeekCommand = { seekTarget = $0 }
        
        coordinator.onPlayCommand?()
        XCTAssertTrue(playCalled, "Play command handler should execute.")
        
        coordinator.onPauseCommand?()
        XCTAssertTrue(pauseCalled, "Pause command handler should execute.")
        
        coordinator.onTogglePlayPauseCommand?()
        XCTAssertTrue(toggleCalled, "Toggle play/pause command handler should execute.")
        
        coordinator.onSkipForwardCommand?(15.0)
        XCTAssertEqual(skipFwdInterval, 15.0, "Skip forward command should pass 15 seconds.")
        
        coordinator.onSkipBackwardCommand?(15.0)
        XCTAssertEqual(skipBackInterval, 15.0, "Skip backward command should pass 15 seconds.")
        
        coordinator.onSeekCommand?(120.0)
        XCTAssertEqual(seekTarget, 120.0, "Seek command should pass 120 seconds target.")
    }
    
    @MainActor
    func testPlaybackEngineLockScreenPlayReplaySupport() {
        let engine = PlaybackEngine.shared
        let track = PlayableTrack(
            id: "test_track_1",
            title: "Mindful Breath",
            courseName: "Basics",
            relativePath: "Packs/1 - Foundation/Basics/Day 01.mp3",
            duration: 600.0
        )
        
        engine.loadAndPlay(track: track)
        XCTAssertEqual(engine.currentTrack?.id, "test_track_1")
        XCTAssertEqual(engine.duration, 600.0)
        
        // Seek to near end and pause
        engine.seek(to: 300.0)
        XCTAssertEqual(engine.currentTime, 300.0)
        
        // Test Skip Forward
        engine.skipForward(15.0)
        XCTAssertEqual(engine.currentTime, 315.0)
        
        // Test Skip Backward
        engine.skipBackward(15.0)
        XCTAssertEqual(engine.currentTime, 300.0)
        
        // Test clamping on seek
        engine.seek(to: 9999.0)
        XCTAssertEqual(engine.currentTime, 600.0)
        
        engine.seek(to: -50.0)
        XCTAssertEqual(engine.currentTime, 0.0)
        
        // Clean up
        engine.stop()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.currentTime, 0.0)
    }
    
    @MainActor
    func testHeadphoneDisconnectHandlerPausesAudio() {
        let engine = PlaybackEngine.shared
        let resolver = LibraryPathResolver.shared
        let relPath = "Packs/2 - Health/1 - Managing Anxiety/session_1.mp3"
        let testURL = resolver.libraryDirectoryURL.appendingPathComponent(relPath)
        
        try? FileManager.default.createDirectory(at: testURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "dummy audio".data(using: .utf8)?.write(to: testURL)
        defer {
            try? FileManager.default.removeItem(at: testURL)
        }
        
        let track = PlayableTrack(
            id: "test_track_airpods",
            title: "Ocean Calm",
            courseName: "Health",
            relativePath: relPath,
            duration: 900.0
        )
        
        engine.loadAndPlay(track: track)
        XCTAssertEqual(engine.state, .playing)
        
        // Simulate headphone disconnect callback from AudioSessionManager
        AudioSessionManager.shared.onHeadphonesDisconnected?()
        
        // Engine must transition to paused to prevent speaker blare
        XCTAssertEqual(engine.state, .paused)
        
        engine.stop()
    }
    
    @MainActor
    func testPlaybackSpeedAdjustment() {
        let engine = PlaybackEngine.shared
        engine.setSpeed(.slow)
        XCTAssertEqual(engine.speed, .slow)
        XCTAssertEqual(engine.speed.rawValue, 0.75)
        XCTAssertEqual(engine.speed.label, "0.75x")
        
        engine.setSpeed(.normal)
        XCTAssertEqual(engine.speed, .normal)
        XCTAssertEqual(engine.speed.rawValue, 1.0)
        
        engine.setSpeed(.fast)
        XCTAssertEqual(engine.speed, .fast)
        XCTAssertEqual(engine.speed.rawValue, 1.25)
        XCTAssertEqual(engine.speed.label, "1.25x")
        
        // Reset to normal
        engine.setSpeed(.normal)
    }
    
    @MainActor
    func testAudioSessionConfigurationExecution() {
        let manager = AudioSessionManager.shared
        manager.configureAudioSession()
        manager.activateSession()
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
        #endif
    }
}
