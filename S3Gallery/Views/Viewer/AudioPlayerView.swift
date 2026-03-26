import SwiftUI
import AVFoundation

@Observable
final class AudioPlayerController: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isLoaded = false
    var error: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            isLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePlayPause() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            stopTimer()
        } else {
            p.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.currentTime = self?.player?.currentTime ?? 0
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
}

struct AudioPlayerView: View {
    let url: URL
    let fileName: String
    var onShare: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var controller = AudioPlayerController()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                Text(fileName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let error = controller.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if controller.isLoaded {
                    playerControls
                } else {
                    ProgressView("Loading...")
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Audio")
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
                    Button("Done") {
                        controller.stop()
                        dismiss()
                    }
                }
            }
            .task { controller.load(url: url) }
            .onDisappear { controller.stop() }
        }
    }

    private var playerControls: some View {
        VStack(spacing: 16) {
            Slider(
                value: Binding(
                    get: { controller.currentTime },
                    set: { controller.seek(to: $0) }
                ),
                in: 0...max(controller.duration, 1)
            )

            HStack {
                Text(controller.currentTime.formattedTime)
                    .font(.caption.monospacedDigit())
                Spacer()
                Text(controller.duration.formattedTime)
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.secondary)

            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
            }
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")
        }
        .padding(.horizontal)
    }
}

private extension TimeInterval {
    var formattedTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
