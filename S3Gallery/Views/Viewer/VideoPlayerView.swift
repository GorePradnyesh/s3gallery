import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let fileName: String
    @Environment(\.dismiss) private var dismiss

    private let player: AVPlayer

    init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
        self.player = AVPlayer(url: url)
    }

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(fileName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
                .onAppear { player.play() }
                .onDisappear { player.pause() }
        }
    }
}
