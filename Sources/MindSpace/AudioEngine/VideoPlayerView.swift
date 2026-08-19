import SwiftUI
import AVKit

#if os(iOS)
import UIKit

/// Custom SwiftUI wrapper presenting an AVPlayer video stream with aspect-fit scaling.
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
        
        public var player: AVPlayer? {
            get { playerLayer.player }
            set {
                playerLayer.player = newValue
                playerLayer.videoGravity = .resizeAspect
            }
        }
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            playerLayer.videoGravity = .resizeAspect
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
#endif
