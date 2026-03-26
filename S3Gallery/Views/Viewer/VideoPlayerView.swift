import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    let fileName: String
    var onShare: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    private let player: AVPlayer

    init(url: URL, fileName: String, onShare: (() -> Void)? = nil) {
        self.url = url
        self.fileName = fileName
        self.onShare = onShare
        self.player = AVPlayer(url: url)
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if onShare != nil {
                        Button {
                            onShare?()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share")
                        .accessibilityIdentifier("Share")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { player.play() }
            .onDisappear { player.pause() }
    }
}
