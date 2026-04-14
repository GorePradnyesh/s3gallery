import Foundation
@testable import S3Gallery

final class MockS3Service: S3ServiceProtocol {
    // MARK: - Configurable responses

    var bucketsResult: Result<[String], Error> = .success(["test-bucket"])
    var objectsResult: Result<[S3Item], Error> = .success([])
    var allObjectsResult: Result<[String], Error> = .success([])
    var presignedURLResult: Result<URL, Error> = .success(URL(string: "https://example.com/presigned")!)
    var checkWriteAccessResult: Result<Bool, Error> = .success(true)
    var uploadObjectResult: Result<Void, Error> = .success(())
    var copyObjectResult: Result<Void, Error> = .success(())
    var deleteObjectResult: Result<Void, Error> = .success(())

    /// Per-call result queue — consumed in order; falls back to `uploadObjectResult` when empty.
    var uploadObjectResults: [Result<Void, Error>] = []

    /// Optional simulated async delay (seconds) added to each upload call.
    var uploadObjectDelay: TimeInterval = 0

    // MARK: - Call tracking

    private let lock = NSLock()
    private(set) var listBucketsCallCount = 0
    private(set) var listObjectsCalls: [(bucket: String, prefix: String)] = []
    private(set) var listAllObjectsCalls: [(bucket: String, prefix: String)] = []
    private(set) var presignedURLCalls: [(item: S3FileItem, ttl: TimeInterval)] = []
    private(set) var checkWriteAccessCalls: [String] = []
    private(set) var uploadObjectCalls: [(bucket: String, key: String, contentType: String)] = []
    private(set) var copyObjectCalls: [(bucket: String, sourceKey: String, destKey: String)] = []
    private(set) var deleteObjectCalls: [(bucket: String, key: String)] = []

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

    func checkWriteAccess(bucket: String) async throws -> Bool {
        checkWriteAccessCalls.append(bucket)
        return try checkWriteAccessResult.get()
    }

    func uploadObject(bucket: String, key: String, data: Data, contentType: String) async throws {
        if uploadObjectDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(uploadObjectDelay * 1_000_000_000))
        }
        let result: Result<Void, Error>
        lock.lock()
        uploadObjectCalls.append((bucket, key, contentType))
        if uploadObjectResults.isEmpty {
            result = uploadObjectResult
        } else {
            result = uploadObjectResults.removeFirst()
        }
        lock.unlock()
        return try result.get()
    }

    func createFolder(bucket: String, key: String) async throws {
        _ = try uploadObjectResult.get()
    }

    func prefixExists(bucket: String, prefix: String) async throws -> Bool {
        return false
    }

    func copyObject(bucket: String, sourceKey: String, destKey: String) async throws {
        copyObjectCalls.append((bucket, sourceKey, destKey))
        return try copyObjectResult.get()
    }

    func deleteObject(bucket: String, key: String) async throws {
        deleteObjectCalls.append((bucket, key))
        return try deleteObjectResult.get()
    }

    func listAllObjects(bucket: String, prefix: String) async throws -> [String] {
        listAllObjectsCalls.append((bucket, prefix))
        return try allObjectsResult.get()
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
