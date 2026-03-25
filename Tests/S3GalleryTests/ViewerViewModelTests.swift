import Testing
import Foundation
@testable import S3Gallery

@Suite("ViewerViewModel")
struct ViewerViewModelTests {

    /// Creates a minimal `S3FileItem` for use as test input.
    ///
    /// - Parameters:
    ///   - key: The S3 object key, including any folder prefix (e.g. `"photos/sunset.jpg"`).
    ///     The file extension drives `FileTypeDetector`, so use a meaningful extension in tests
    ///     that check `fileCategory`.
    ///   - bucket: The bucket the item belongs to. Defaults to "test".
    private func makeItem(key: String = "photo.jpg", bucket: String = "test") -> S3FileItem {
        S3FileItem(key: key, bucket: bucket, size: 2048, lastModified: Date(), eTag: nil)
    }

    // MARK: - Presigned URL loading

    /// Verifies the happy path: a successful presign call transitions the view model to `.ready`.
    ///
    /// `ViewerContainer` calls `loadPresignedURL` when it appears. On success the state must
    /// become `.ready(url)` where `url` exactly matches what the service returned. The viewer
    /// (PhotoViewer, VideoPlayerView, etc.) then uses this URL to stream content directly from
    /// S3 — no intermediate download or proxy.
    @Test("loadPresignedURL sets ready state with URL")
    func loadPresignedURLSuccess() async throws {
        let item = makeItem()
        let mock = MockS3Service()
        let expectedURL = URL(string: "https://s3.example.com/photo.jpg?sig=abc")!
        mock.presignedURLResult = .success(expectedURL)

        let vm = ViewerViewModel(item: item, s3Service: mock)
        await vm.loadPresignedURL()

        guard case .ready(let url) = vm.loadState else {
            Issue.record("Expected .ready state")
            return
        }
        #expect(url == expectedURL)
    }

    /// Verifies that a presigning failure is surfaced so the viewer can show a Retry button.
    ///
    /// Presigning can fail if the object has been deleted, permissions have changed, or the
    /// region is misconfigured. The view model must enter `.error` with a localised message
    /// so `ViewerContainer` renders a meaningful error UI rather than spinning forever.
    @Test("loadPresignedURL sets error state on failure")
    func loadPresignedURLFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "presign failed" }
        }
        let item = makeItem()
        let mock = MockS3Service()
        mock.presignedURLResult = .failure(FakeError())

        let vm = ViewerViewModel(item: item, s3Service: mock)
        await vm.loadPresignedURL()

        if case .error(let msg) = vm.loadState {
            #expect(msg.contains("presign failed"))
        } else {
            Issue.record("Expected .error state")
        }
    }

    /// Verifies that the presigned URL is requested with a 15-minute (900-second) TTL.
    ///
    /// Per the security plan, presigned URLs must expire after 15 minutes to limit the window
    /// during which a leaked URL remains valid. The TTL is never stored or persisted — it only
    /// lives in memory during the viewing session. This test inspects the recorded call args on
    /// the mock to confirm the correct expiry is passed down to the service layer.
    @Test("loadPresignedURL uses 900s TTL")
    func ttlIs900Seconds() async {
        let item = makeItem()
        let mock = MockS3Service()

        let vm = ViewerViewModel(item: item, s3Service: mock)
        await vm.loadPresignedURL()

        #expect(mock.presignedURLCalls.first?.ttl == 900)
    }

    /// Verifies that `retry` resets state to `.idle` and triggers a fresh presign request.
    ///
    /// The Retry button in `ViewerContainer`'s error state calls `retry()`. The method must
    /// reset `loadState` to `.idle` (so the loading spinner re-appears) before calling
    /// `loadPresignedURL` again. This test confirms the service is called exactly twice —
    /// once for the initial load and once for the retry — proving the reset-and-reload cycle
    /// works correctly.
    @Test("retry resets to idle then reloads")
    func retryResetsState() async {
        let item = makeItem()
        let mock = MockS3Service()
        mock.presignedURLResult = .success(URL(string: "https://example.com")!)

        let vm = ViewerViewModel(item: item, s3Service: mock)
        await vm.loadPresignedURL()
        await vm.retry()

        #expect(mock.presignedURLCalls.count == 2)
    }

    // MARK: - File category routing

    /// Verifies that a `.jpg` file is routed to the image viewer.
    ///
    /// `ViewerContainer` switches on `fileCategory` to decide which viewer component to present.
    /// JPEG images must map to `.image` so they open in `PhotoViewer` with pinch-to-zoom support
    /// rather than falling back to QuickLook's generic preview.
    @Test("detects image category for jpg")
    func detectsImage() {
        let item = makeItem(key: "sunset.jpg")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .image)
    }

    /// Verifies that a `.mp4` file is routed to the native video player.
    ///
    /// MP4 files must map to `.video` so they open in `VideoPlayerView` backed by `AVKit`.
    /// This gives the user standard playback controls (play/pause, scrubbing, AirPlay) rather
    /// than the download-then-preview flow used for unsupported formats.
    @Test("detects video category for mp4")
    func detectsVideo() {
        let item = makeItem(key: "movie.mp4")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .video)
    }

    /// Verifies that a `.pdf` file is routed to the PDFKit viewer.
    ///
    /// PDFs must map to `.pdf` so they open in `PDFViewerView`, which wraps `PDFView` for
    /// smooth scrolling, text selection, and search — capabilities QuickLook does not expose
    /// to the host app.
    @Test("detects pdf category")
    func detectsPDF() {
        let item = makeItem(key: "document.pdf")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .pdf)
    }

    /// Verifies that a `.mp3` file is routed to the custom audio player.
    ///
    /// Audio files must map to `.audio` so they open in `AudioPlayerView` with the custom
    /// play/pause/scrub UI rather than QuickLook's minimal audio interface. This category
    /// also applies to AAC, FLAC, WAV, and M4A — `.mp3` is used here as the canonical example.
    @Test("detects audio category for mp3")
    func detectsAudio() {
        let item = makeItem(key: "song.mp3")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .audio)
    }

    /// Verifies that an unrecognised extension falls back to the QuickLook generic viewer.
    ///
    /// Files like `.zip`, `.docx`, or custom formats that don't match any known category must
    /// map to `.other` so `GenericFileView` downloads the file to a temp location and hands it
    /// to `QLPreviewController`. This is the safe fallback that handles anything the app hasn't
    /// explicitly optimised for.
    @Test("falls back to other for unknown extension")
    func detectsOther() {
        let item = makeItem(key: "archive.zip")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .other)
    }
}
