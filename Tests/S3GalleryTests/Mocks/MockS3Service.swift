import Foundation
@testable import S3Gallery

final class MockS3Service: S3ServiceProtocol {
    // MARK: - Configurable responses

    var bucketsResult: Result<[String], Error> = .success(["test-bucket"])
    var objectsResult: Result<[S3Item], Error> = .success([])
    var presignedURLResult: Result<URL, Error> = .success(URL(string: "https://example.com/presigned")!)

    // MARK: - Call tracking

    private(set) var listBucketsCallCount = 0
    private(set) var listObjectsCalls: [(bucket: String, prefix: String)] = []
    private(set) var presignedURLCalls: [(item: S3FileItem, ttl: TimeInterval)] = []

    // MARK: - S3ServiceProtocol

    func listBuckets() async throws -> [String] {
        listBucketsCallCount += 1
        return try bucketsResult.get()
    }

    func listObjects(bucket: String, prefix: String) async throws -> [S3Item] {
        listObjectsCalls.append((bucket, prefix))
        return try objectsResult.get()
    }

    func presignedURL(for item: S3FileItem, ttl: TimeInterval) async throws -> URL {
        presignedURLCalls.append((item, ttl))
        return try presignedURLResult.get()
    }

    // MARK: - Helpers for test setup

    static func makeFolders(_ names: [String], bucket: String = "test-bucket") -> [S3Item] {
        names.map { name in
            S3Item.folder(name: name, prefix: "\(name)/")
        }
    }

    static func makeFiles(_ names: [String], bucket: String = "test-bucket") -> [S3Item] {
        names.map { name in
            S3Item.file(S3FileItem(
                key: name,
                bucket: bucket,
                size: 1024,
                lastModified: Date(),
                eTag: nil
            ))
        }
    }
}

final class MockCredentialsService: CredentialsServiceProtocol {
    var stored: Credentials?
    var saveError: Error?
    var loadError: Error?
    var deleteError: Error?

    private(set) var saveCalled = false
    private(set) var loadCalled = false
    private(set) var deleteCalled = false

    func save(_ credentials: Credentials) throws {
        saveCalled = true
        if let error = saveError { throw error }
        stored = credentials
    }

    func load() throws -> Credentials? {
        loadCalled = true
        if let error = loadError { throw error }
        return stored
    }

    func delete() throws {
        deleteCalled = true
        if let error = deleteError { throw error }
        stored = nil
    }
}
