import SwiftUI
import UIKit

/// High-performance, tactile sensory feedback service for MindSpace iOS.
/// Follows Apple Human Interface Guidelines for subtle, non-intrusive haptic cues.
/// Designed for safe synchronous invocation from any SwiftUI view modifier or ButtonStyle.
/// Uses retained generator singletons to prevent repeated system IPC and battery consumption.
public final class HapticService: @unchecked Sendable {
    public static let shared = HapticService()
    
    #if os(iOS)
    @MainActor private lazy var lightImpact = UIImpactFeedbackGenerator(style: .light)
    @MainActor private lazy var mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    @MainActor private lazy var softImpact = UIImpactFeedbackGenerator(style: .soft)
    @MainActor private lazy var selectionFeedback = UISelectionFeedbackGenerator()
    @MainActor private lazy var notificationFeedback = UINotificationFeedbackGenerator()
    #endif
    
    private init() {}
    
    /// Trigger light impact for standard button presses, tab switches, and chips
    public func light() {
        #if os(iOS)
        dispatchOnMain {
            self.lightImpact.impactOccurred()
            self.lightImpact.prepare()
        }
        #endif
    }
    
    /// Trigger medium impact for play/pause toggle and primary CTA buttons
    public func medium() {
        #if os(iOS)
        dispatchOnMain {
            self.mediumImpact.impactOccurred()
            self.mediumImpact.prepare()
        }
        #endif
    }
    
    /// Trigger soft impact during audio scrubber scrubbing and slider movement
    public func soft() {
        #if os(iOS)
        dispatchOnMain {
            self.softImpact.impactOccurred(intensity: 0.7)
            self.softImpact.prepare()
        }
        #endif
    }
    
    /// Trigger selection tick when scrolling through discrete items or dates
    public func selection() {
        #if os(iOS)
        dispatchOnMain {
            self.selectionFeedback.selectionChanged()
            self.selectionFeedback.prepare()
        }
        #endif
    }
    
    /// Trigger success notification when completing a session or earning an achievement
    public func success() {
        #if os(iOS)
        dispatchOnMain {
            self.notificationFeedback.notificationOccurred(.success)
            self.notificationFeedback.prepare()
        }
        #endif
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
