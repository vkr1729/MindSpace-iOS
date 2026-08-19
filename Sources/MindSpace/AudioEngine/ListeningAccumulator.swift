import Foundation

/// Anti-scrubbing listening accumulator that calculates verified mindful listening duration
/// rather than trusting the user's scrubber position.
@MainActor
public final class ListeningAccumulator: ObservableObject {
    public let duration: Double
    public let targetThreshold: Double
    @Published public private(set) var accumulatedSeconds: Double = 0.0
    private var lastObservedTime: Double?
    
    public init(duration: Double) {
        self.duration = duration
        // Threshold: at least 60s, or 90% of duration, or duration - 30s
        self.targetThreshold = max(60.0, min(duration * 0.90, max(0.0, duration - 30.0)))
    }
    
    /// Records a playback tick. Only accumulates real-time forwards progression.
    public func tick(currentTime: Double, isPlaying: Bool) {
        guard isPlaying else {
            lastObservedTime = nil
            return
        }
        
        if let last = lastObservedTime {
            let delta = currentTime - last
            // Valid forward progression between 0 and 1.5 seconds
            if delta > 0.0 && delta <= 1.5 {
                accumulatedSeconds += delta
            }
        }
        lastObservedTime = currentTime
    }
    
    /// Resets the accumulator state.
    public func reset() {
        accumulatedSeconds = 0.0
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
