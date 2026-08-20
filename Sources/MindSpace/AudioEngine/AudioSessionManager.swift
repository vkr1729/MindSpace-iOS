import Foundation
import AVFoundation

#if os(iOS)
import UIKit
#endif

/// Manages system audio session configuration, interruptions, and route changes (headphone disconnects).
@MainActor
public final class AudioSessionManager: ObservableObject {
    public static let shared = AudioSessionManager()
    
    public var onInterruptionBegan: (() -> Void)?
    public var onInterruptionEndedShouldResume: (() -> Void)?
    public var onHeadphonesDisconnected: (() -> Void)?
    
    private var isConfigured = false
    
    public init() {
        setupNotifications()
    }
    
    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if !isConfigured {
                try session.setCategory(
                    .playback,
                    mode: .default,
                    options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
                )
                isConfigured = true
            }
            try session.setActive(true)
        } catch {
            print("Failed to configure/activate AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
    
    public func activateSession() {
        configureAudioSession()
    }
    
    public func deactivateSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func setupNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification: notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification: notification)
        }
        #endif
    }
    
    #if os(iOS)
    private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    onInterruptionEndedShouldResume?()
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // When AirPods / Bluetooth headphones disconnect, immediately pause to avoid speaker blare
        if reason == .oldDeviceUnavailable {
            onHeadphonesDisconnected?()
        }
    }
    #endif
}
