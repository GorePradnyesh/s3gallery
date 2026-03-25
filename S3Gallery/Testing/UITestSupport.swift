#if DEBUG
import Foundation

// MARK: - Launch argument detection

enum UITestArgs {
    static var isUITesting:  Bool { CommandLine.arguments.contains("--uitesting") }
    static var skipLogin:    Bool { CommandLine.arguments.contains("--skip-login") }
    static var noKeychain:   Bool { CommandLine.arguments.contains("--no-keychain") }
    static var mockSuccess:  Bool { CommandLine.arguments.contains("--mock-s3-success") }
    static var mockFailure:  Bool { CommandLine.arguments.contains("--mock-s3-failure") }
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
                .file(S3FileItem(key: "readme.txt", bucket: bucket, size: 512,
                                 lastModified: Date(), eTag: nil)),
                .file(S3FileItem(key: "sunset.jpg", bucket: bucket, size: 2_048_000,
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
}

enum UITestError: Error, LocalizedError {
    case invalidCredentials
    var errorDescription: String? { "Invalid credentials (UI test mock failure)" }
}
#endif
