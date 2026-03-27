#if DEBUG
import Foundation

// MARK: - Launch argument detection

enum UITestArgs {
    static var isUITesting:  Bool { CommandLine.arguments.contains("--uitesting") }
    static var skipLogin:    Bool { CommandLine.arguments.contains("--skip-login") }
    static var noKeychain:   Bool { CommandLine.arguments.contains("--no-keychain") }
    static var mockSuccess:  Bool { CommandLine.arguments.contains("--mock-s3-success") }
    static var mockFailure:  Bool { CommandLine.arguments.contains("--mock-s3-failure") }
    static var mockReadOnly:        Bool { CommandLine.arguments.contains("--mock-read-only") }
    static var autoUpload:          Bool { CommandLine.arguments.contains("--auto-upload") }
    static var mockUploadFailure:   Bool { CommandLine.arguments.contains("--mock-upload-failure") }
    static var autoStage:           Bool { CommandLine.arguments.contains("--auto-stage") }
    static var mockPartialFailure:  Bool { CommandLine.arguments.contains("--mock-partial-failure") }
    static var mockFileAction:      Bool { CommandLine.arguments.contains("--mock-file-action") }
}

// MARK: - In-process mock S3 service for UI tests

/// A lightweight S3 service stub injected into the app when launched with
/// `--uitesting`. Returns deterministic canned data so UI tests don't need
/// real AWS credentials or network access.
final class UITestMockS3Service: S3ServiceProtocol {
    private let shouldSucceed: Bool

    init(shouldSucceed: Bool) {
        self.shouldSucceed = shouldSucceed
    }

    func listBuckets() async throws -> [String] {
        guard shouldSucceed else { throw UITestError.invalidCredentials }
        return ["test-bucket", "photos-bucket"]
    }

    func listObjects(bucket: String, prefix: String) async throws -> [S3Item] {
        guard shouldSucceed else { throw UITestError.invalidCredentials }
        if prefix.isEmpty {
            return [
                .folder(name: "photos", prefix: "photos/"),
                .folder(name: "videos", prefix: "videos/"),
                .file(S3FileItem(key: "autumn.jpg", bucket: bucket, size: 1_800_000,
                                 lastModified: Date(), eTag: nil)),
                .file(S3FileItem(key: "readme.txt", bucket: bucket, size: 512,
                                 lastModified: Date(), eTag: nil)),
                .file(S3FileItem(key: "sunset.jpg", bucket: bucket, size: 2_048_000,
                                 lastModified: Date(), eTag: nil)),
                .file(S3FileItem(key: "sample.mp4", bucket: bucket, size: 512_000,
                                 lastModified: Date(), eTag: nil)),
            ]
        }
        return [
            .file(S3FileItem(key: "\(prefix)photo1.jpg", bucket: bucket, size: 1_024_000,
                             lastModified: Date(), eTag: nil)),
        ]
    }

    func presignedURL(for item: S3FileItem, ttl: TimeInterval) async throws -> URL {
        URL(string: "https://test.s3.example.com/\(item.key)?mock=1")!
    }

    func checkWriteAccess(bucket: String) async throws -> Bool {
        guard shouldSucceed else { throw UITestError.invalidCredentials }
        return !UITestArgs.mockReadOnly
    }

    private var uploadCallCount = 0

    func uploadObject(bucket: String, key: String, data: Data, contentType: String) async throws {
        guard shouldSucceed else { throw UITestError.invalidCredentials }
        if UITestArgs.mockUploadFailure { throw UITestError.uploadFailed }
        if UITestArgs.mockPartialFailure {
            uploadCallCount += 1
            if uploadCallCount == 2 { throw UITestError.uploadFailed }
        }
    }
}

enum UITestError: Error, LocalizedError {
    case invalidCredentials
    case uploadFailed
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid credentials (UI test mock failure)"
        case .uploadFailed: return "Upload failed (UI test mock failure)"
        }
    }
}
#endif
