import Foundation

/// Anti-scrubbing listening accumulator that calculates verified mindful listening duration
/// rather than trusting the user's scrubber position.
///
/// Crediting Decision for Playback Speeds (0.75x, 1.0x, 1.25x):
/// - Track progression (`accumulatedSeconds`) measures continuous audio track duration listened.
/// - Legitimate forward progression is defined as continuous playback where delta <= (2.0 * speed).
/// - Seeking or scrubbing forward produces a large positive jump (e.g., +15s or +300s) which is rejected.
/// - Uninterrupted full playback at 0.75x, 1.0x, or 1.25x advances continuously and accumulates the full
///   track duration, guaranteeing that listening at any allowed speed qualifies for streak credit without loss.
/// - `actualPlayedSeconds` tracks wall-clock physical time spent listening (delta / speed).
@MainActor
public final class ListeningAccumulator: ObservableObject {
    public let duration: Double
    public let targetThreshold: Double
    
    /// Accumulated audio track seconds (used for meeting content duration threshold)
    @Published public private(set) var accumulatedSeconds: Double = 0.0
    
    /// Accumulated real-world wall-clock seconds spent listening
    @Published public private(set) var actualPlayedSeconds: Double = 0.0
    
    private var lastObservedTime: Double?
    
    public init(duration: Double) {
        self.duration = duration
        // Threshold: at least 60s, or 90% of duration, or duration - 30s
        self.targetThreshold = max(60.0, min(duration * 0.90, max(0.0, duration - 30.0)))
    }
    
    /// Records a playback tick with optional playback speed.
    /// Only accumulates continuous forward progression, rejecting seeking/scrubbing jumps.
    public func tick(currentTime: Double, isPlaying: Bool, speed: Double = 1.0) {
        guard isPlaying else {
            lastObservedTime = nil
            return
        }
        
        let effectiveSpeed = max(0.5, speed)
        
        if let last = lastObservedTime {
            let delta = currentTime - last
            // Valid forward progression threshold scales with playback rate (allowing up to 2.0s * rate for timer jitter)
            let maxAllowedDelta = max(1.5, 2.0 * effectiveSpeed)
            if delta > 0.0 && delta <= maxAllowedDelta {
                accumulatedSeconds += delta
                actualPlayedSeconds += (delta / effectiveSpeed)
            }
        }
        lastObservedTime = currentTime
    }
    
    /// Resets the accumulator state.
    public func reset() {
        accumulatedSeconds = 0.0
        actualPlayedSeconds = 0.0
        lastObservedTime = nil
    }
    
    /// Returns whether the user has satisfied the anti-scrubbing criteria for completion.
    public var hasQualified: Bool {
        // If duration is under 60 seconds, qualify when >= 80% duration
        if duration < 60.0 {
            return accumulatedSeconds >= (duration * 0.80)
        }
        return accumulatedSeconds >= targetThreshold
    }
    
    public var completionPercentage: Double {
        guard targetThreshold > 0 else { return 0 }
        return min(1.0, accumulatedSeconds / targetThreshold)
    }
}

