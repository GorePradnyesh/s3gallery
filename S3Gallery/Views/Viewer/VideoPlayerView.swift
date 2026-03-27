import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let url: URL
    let fileName: String

    var body: some View {
        ZStack {
            Color.black
            Button(action: openPlayer) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .accessibilityLabel("Play \(fileName)")
        }
        .ignoresSafeArea()
    }

    private func openPlayer() {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let presenter = window.rootViewController?.topmostPresented()
        else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let playerVC = AVPlayerViewController()
        playerVC.player = AVPlayer(url: url)
        playerVC.showsPlaybackControls = true
        playerVC.modalPresentationStyle = .fullScreen

        presenter.present(playerVC, animated: true) {
            playerVC.player?.play()
        }
    }
}

private extension UIViewController {
    func topmostPresented() -> UIViewController {
        presentedViewController?.topmostPresented() ?? self
    }
}
