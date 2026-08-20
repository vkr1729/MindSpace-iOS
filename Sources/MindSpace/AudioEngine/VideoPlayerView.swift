import SwiftUI
import AVKit

#if os(iOS)
import UIKit

/// Custom SwiftUI wrapper presenting an AVPlayer video stream with aspect-fit scaling.
/// Automatically handles background/lock-screen transitions to ensure audio never stalls.
public struct VideoPlayerView: UIViewRepresentable {
    public let player: AVPlayer?
    
    public init(player: AVPlayer?) {
        self.player = player
    }
    
    public func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    public func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
    
    public final class PlayerUIView: UIView {
        public override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }
        
        public var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
        
        private var storedPlayer: AVPlayer?
        private var notificationTokens: [Any] = []
        
        public var player: AVPlayer? {
            get { storedPlayer }
            set {
                storedPlayer = newValue
                playerLayer.player = newValue
                playerLayer.videoGravity = .resizeAspect
            }
        }
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            playerLayer.videoGravity = .resizeAspect
            setupBackgroundObservers()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            for token in notificationTokens {
                NotificationCenter.default.removeObserver(token)
            }
        }
        
        private func setupBackgroundObservers() {
            let bgToken = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // Detach player from layer so AVPlayer does not pause playback when device locks
                self?.playerLayer.player = nil
            }
            
            let fgToken = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // Reconnect player when app returns to foreground
                guard let self = self else { return }
                self.playerLayer.player = self.storedPlayer
            }
            
            notificationTokens = [bgToken, fgToken]
        }
    }
}

/// Full-screen native video player controller wrapper with controls, rotation, and dismiss handling.
@MainActor
public struct FullScreenVideoPlayerViewController: UIViewControllerRepresentable {
    public let player: AVPlayer?
    public let onDismiss: (@MainActor () -> Void)?
    
    public init(player: AVPlayer?, onDismiss: (@MainActor () -> Void)? = nil) {
        self.player = player
        self.onDismiss = onDismiss
    }
    
    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = true
        controller.videoGravity = .resizeAspect
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    @MainActor
    public final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: (@MainActor () -> Void)?
        
        init(onDismiss: (@MainActor () -> Void)?) {
            self.onDismiss = onDismiss
        }
        
        public func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
        ) {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.onDismiss?()
            }
        }
    }
}
#else
public struct VideoPlayerView: View {
    public let player: AVPlayer?
    public init(player: AVPlayer?) { self.player = player }
    public var body: some View {
        Rectangle().fill(Color.black)
    }
}

public struct FullScreenVideoPlayerViewController: View {
    public let player: AVPlayer?
    public let onDismiss: (() -> Void)?
    public init(player: AVPlayer?, onDismiss: (() -> Void)? = nil) {
        self.player = player
        self.onDismiss = onDismiss
    }
    public var body: some View {
        Rectangle().fill(Color.black)
    }
}
#endif
