import SwiftUI
import AVKit

struct AVPlayerView: UIViewRepresentable {
    var player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = .black
        view.playerLayer.player = player
        // resizeAspect = letterbox/pillarbox: video keeps its own aspect ratio
        // black bars fill the rest of the canvas — canvas shape stays as selected
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

class PlayerUIView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    // Ensure the playerLayer always fills the view bounds exactly
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
