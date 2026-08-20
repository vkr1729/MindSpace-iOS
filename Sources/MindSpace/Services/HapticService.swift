import SwiftUI
import UIKit

/// High-performance, tactile sensory feedback service for MindSpace iOS.
/// Follows Apple Human Interface Guidelines for subtle, non-intrusive haptic cues.
/// Designed for safe synchronous invocation from any SwiftUI view modifier or ButtonStyle.
public final class HapticService: @unchecked Sendable {
    public static let shared = HapticService()
    
    private init() {}
    
    /// Trigger light impact for standard button presses, tab switches, and chips
    public func light() {
        dispatchOnMain {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    /// Trigger medium impact for play/pause toggle and primary CTA buttons
    public func medium() {
        dispatchOnMain {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    /// Trigger soft impact during audio scrubber scrubbing and slider movement
    public func soft() {
        dispatchOnMain {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.7)
        }
    }
    
    /// Trigger selection tick when scrolling through discrete items or dates
    public func selection() {
        dispatchOnMain {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }
    
    /// Trigger success notification when completing a session or earning an achievement
    public func success() {
        dispatchOnMain {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
    
    private func dispatchOnMain(_ action: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                action()
            }
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }
}
