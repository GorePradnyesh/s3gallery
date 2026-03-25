import Testing
import Foundation
@testable import S3Gallery

/// Integration tests that run against real AWS infrastructure.
/// Run on-demand with: xcodebuild -scheme S3GalleryIntegrationTests
///
/// Required environment variables:
///   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_TEST_BUCKET
///
/// The test bucket must be read-only and contain at least one object.
@Suite("S3Service Integration", .disabled("Requires real AWS credentials — set env vars and remove .disabled"))
struct S3ServiceIntegrationTests {

    private func makeService() async throws -> S3Service {
        let keyId = try requiredEnv("AWS_ACCESS_KEY_ID")
        let secret = try requiredEnv("AWS_SECRET_ACCESS_KEY")
        let region = try requiredEnv("AWS_REGION")
        let credentials = Credentials(accessKeyId: keyId, secretAccessKey: secret, region: region)
        return try await S3Service(credentials: credentials)
    }

    @Test("listBuckets returns at least one bucket")
    func listBuckets() async throws {
        let service = try await makeService()
        let buckets = try await service.listBuckets()
        #expect(!buckets.isEmpty)
    }

    @Test("listObjects returns items for test bucket root")
    func listObjectsRoot() async throws {
        let bucket = try requiredEnv("S3_TEST_BUCKET")
        let service = try await makeService()
        let items = try await service.listObjects(bucket: bucket, prefix: "")
        #expect(!items.isEmpty)
    }

    @Test("presignedURL generates a valid URL for first file in test bucket")
    func presignedURL() async throws {
        let bucket = try requiredEnv("S3_TEST_BUCKET")
        let service = try await makeService()
        let items = try await service.listObjects(bucket: bucket, prefix: "")

        guard let firstFile = items.compactMap({ $0.fileItem }).first else {
            Issue.record("No files found in test bucket")
            return
        }

        let url = try await service.presignedURL(for: firstFile, ttl: 300)
        #expect(url.scheme == "https")
        #expect(url.host?.contains("amazonaws.com") == true)
    }

    @Test("checkWriteAccess returns true on a writable bucket")
    func checkWriteAccess() async throws {
        let bucket = try requiredEnv("S3_TEST_BUCKET_WRITABLE")
        let service = try await makeService()
        let hasWrite = try await service.checkWriteAccess(bucket: bucket)
        #expect(hasWrite == true)
    }

    @Test("uploadObject uploads a small file that appears in listObjects")
    func uploadObject() async throws {
        let bucket = try requiredEnv("S3_TEST_BUCKET_WRITABLE")
        let service = try await makeService()

        let testKey = "s3gallery-integration-test-\(Int(Date().timeIntervalSince1970)).txt"
        let data = Data("integration test upload".utf8)

        try await service.uploadObject(bucket: bucket, key: testKey, data: data, contentType: "text/plain")

        let items = try await service.listObjects(bucket: bucket, prefix: "")
        let keys = items.compactMap { $0.fileItem?.key }
        #expect(keys.contains(testKey))
    }

    private func requiredEnv(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            throw IntegrationTestError.missingEnvVar(key)
        }
        return value
    }
}

private enum IntegrationTestError: Error, LocalizedError {
    case missingEnvVar(String)
    var errorDescription: String? {
        if case .missingEnvVar(let key) = self { return "Missing env var: \(key)" }
        return nil
    }
}
