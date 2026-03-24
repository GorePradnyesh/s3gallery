import Testing
import Foundation
@testable import S3Gallery

@Suite("ViewerViewModel")
struct ViewerViewModelTests {

    private func makeItem(key: String = "photo.jpg", bucket: String = "test") -> S3FileItem {
        S3FileItem(key: key, bucket: bucket, size: 2048, lastModified: Date(), eTag: nil)
    }

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

    @Test("loadPresignedURL uses 900s TTL")
    func ttlIs900Seconds() async {
        let item = makeItem()
        let mock = MockS3Service()

        let vm = ViewerViewModel(item: item, s3Service: mock)
        await vm.loadPresignedURL()

        #expect(mock.presignedURLCalls.first?.ttl == 900)
    }

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

    @Test("detects image category for jpg")
    func detectsImage() {
        let item = makeItem(key: "sunset.jpg")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .image)
    }

    @Test("detects video category for mp4")
    func detectsVideo() {
        let item = makeItem(key: "movie.mp4")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .video)
    }

    @Test("detects pdf category")
    func detectsPDF() {
        let item = makeItem(key: "document.pdf")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .pdf)
    }

    @Test("detects audio category for mp3")
    func detectsAudio() {
        let item = makeItem(key: "song.mp3")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .audio)
    }

    @Test("falls back to other for unknown extension")
    func detectsOther() {
        let item = makeItem(key: "archive.zip")
        let vm = ViewerViewModel(item: item, s3Service: MockS3Service())
        #expect(vm.fileCategory == .other)
    }
}
