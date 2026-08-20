import SwiftUI
import UIKit

/// High-performance, tactile sensory feedback service for MindSpace iOS.
/// Follows Apple Human Interface Guidelines for subtle, non-intrusive haptic cues.
@MainActor
public final class HapticService {
    public static let shared = HapticService()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-warm light generator for instant response on user touch
        lightImpact.prepare()
    }
    
    /// Trigger light impact for standard button presses, tab switches, and chips
    public func light() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Trigger medium impact for play/pause toggle and primary CTA buttons
    public func medium() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Trigger soft impact during audio scrubber scrubbing and slider movement
    public func soft() {
        softImpact.impactOccurred(intensity: 0.7)
        softImpact.prepare()
    }
    
    /// Trigger selection tick when scrolling through discrete items or dates
    public func selection() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }
    
    /// Trigger success notification when completing a session or earning an achievement
    public func success() {
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }
}
