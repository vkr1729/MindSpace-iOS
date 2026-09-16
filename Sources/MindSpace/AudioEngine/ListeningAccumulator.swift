import Foundation

/// Anti-scrubbing listening accumulator that calculates verified mindful listening duration
/// rather than trusting the user's scrubber position.
///
/// Crediting Decision for Playback Speeds (0.75x, 1.0x, 1.25x):
/// - Track progression (`accumulatedSeconds`) measures unique continuous audio track duration listened.
/// - Range union prevents double-counting if the user rewinds and replays a segment.
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
    
    /// Listened disjoint range intervals [start, end]
    private var listenedRanges: [(start: Double, end: Double)] = []
    
    private var lastObservedTime: Double?
    
    public init(
        duration: Double,
        initialAccumulatedSeconds: Double = 0.0,
        restoredListenedSeconds: Double? = nil
    ) {
        self.duration = duration
        // Threshold: at least 60s, or 90% of duration, or duration - 30s
        self.targetThreshold = max(60.0, min(duration * 0.90, max(0.0, duration - 30.0)))
        let startSecs = restoredListenedSeconds ?? initialAccumulatedSeconds
        if startSecs > 0.0 {
            let clamped = min(duration, max(0.0, startSecs))
            self.accumulatedSeconds = clamped
            self.actualPlayedSeconds = clamped
            self.listenedRanges = [(0.0, clamped)]
        }
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
                addRange(start: last, end: currentTime)
                accumulatedSeconds = computeTotalListenedSeconds()
                actualPlayedSeconds += (delta / effectiveSpeed)
            }
        }
        lastObservedTime = currentTime
    }
    
    private func addRange(start: Double, end: Double) {
        let rStart = max(0.0, min(start, end))
        let rEnd = min(duration > 0 ? duration : end, max(start, end))
        guard rEnd > rStart else { return }
        
        var newRanges = listenedRanges
        newRanges.append((rStart, rEnd))
        newRanges.sort { $0.start < $1.start }
        
        var merged: [(start: Double, end: Double)] = []
        for range in newRanges {
            if let last = merged.last {
                if range.start <= last.end + 0.5 { // Overlapping or adjacent
                    merged[merged.count - 1] = (last.start, max(last.end, range.end))
                } else {
                    merged.append(range)
                }
            } else {
                merged.append(range)
            }
        }
        self.listenedRanges = merged
    }
    
    private func computeTotalListenedSeconds() -> Double {
        listenedRanges.reduce(0.0) { $0 + ($1.end - $1.start) }
    }
    
    /// Resets the accumulator state.
    public func reset() {
        accumulatedSeconds = 0.0
        actualPlayedSeconds = 0.0
        listenedRanges.removeAll()
        lastObservedTime = nil
    }
    
    /// Returns whether the user has satisfied the anti-scrubbing criteria for completion.
    public var hasQualified: Bool {
        guard duration > 0 else { return false }
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
