import XCTest
import AVFoundation
@testable import MindSpace

final class PlaybackStreamingTests: XCTestCase {
    
    // MARK: - Remote URL Path Encoding Test
    func testRemoteStreamAssetURLEncoding() {
        let relativePath = "Packs/1 - Foundation/Basics 1/MindSpace - Basics 1 - Day 01.mp3"
        let components = relativePath.split(separator: "/").map {
            $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }
        let encodedPath = components.joined(separator: "/")
        
        let expected = "Packs/1%20-%20Foundation/Basics%201/MindSpace%20-%20Basics%201%20-%20Day%2001.mp3"
        XCTAssertEqual(encodedPath, expected)
        
        let repo = "vkr1729/MindSpace-Content"
        let fullURLString = "https://raw.githubusercontent.com/\(repo)/main/\(encodedPath)"
        let url = URL(string: fullURLString)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "raw.githubusercontent.com")
    }
    
    // MARK: - Local Priority vs Remote Fallback
    func testLocalPriorityOverRemoteStream() {
        let nonExistentPath = "NonExistentPack/TestTrack.mp3"
        let localURL = LibraryPathResolver.shared.resolveURL(for: nonExistentPath)
        XCTAssertNil(localURL, "Missing file should return nil for local resolution")
    }
    
    // MARK: - PlayableTrack Construction & Streaming Metadata
    func testPlayableTrackConstruction() {
        let track = PlayableTrack(
            id: "singles_sleep_rain_10m",
            title: "Rain on Tent (10 min)",
            courseName: "Sleep Sounds",
            relativePath: "Singles/5 - Sleep Sounds/MindSpace - Sleep Sounds - Rain on Tent 10m.mp3",
            duration: 600.0,
            contentType: "sleep"
        )
        
        XCTAssertEqual(track.id, "singles_sleep_rain_10m")
        XCTAssertEqual(track.title, "Rain on Tent (10 min)")
        XCTAssertEqual(track.courseName, "Sleep Sounds")
        XCTAssertEqual(track.duration, 600.0)
        XCTAssertEqual(track.contentType, "sleep")
    }
}
