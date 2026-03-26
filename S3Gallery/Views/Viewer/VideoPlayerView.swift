import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let fileName: String

    private let player: AVPlayer

    init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
        self.player = AVPlayer(url: url)
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea(edges: .bottom)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
    }
}
