import Testing
import Foundation
@testable import S3Gallery

// MARK: - Mock URLProtocol

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeURL() -> URL {
    URL(string: "https://mock.s3.example.com/test-key")!
}

// MARK: - Tests

@Suite("FileActionService")
@MainActor
struct FileActionServiceTests {

    @Test("download writes file to unique temp path")
    func downloadSuccess() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: makeURL(),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("hello world".utf8))
        }

        let service = FileActionService(session: makeSession())
        let local = try await service.download(presignedURL: makeURL(), fileName: "photo.jpg")
        defer { service.cleanup(url: local) }

        #expect(FileManager.default.fileExists(atPath: local.path))
        #expect(local.lastPathComponent == "photo.jpg")
        let contents = try Data(contentsOf: local)
        #expect(contents == Data("hello world".utf8))
    }

    @Test("download throws on HTTP error")
    func downloadHttpError() async {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: makeURL(),
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = FileActionService(session: makeSession())
        await #expect(throws: (any Error).self) {
            _ = try await service.download(presignedURL: makeURL(), fileName: "photo.jpg")
        }
    }

    @Test("download throws on network error")
    func downloadNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let service = FileActionService(session: makeSession())
        await #expect(throws: (any Error).self) {
            _ = try await service.download(presignedURL: makeURL(), fileName: "photo.jpg")
        }
    }

    @Test("cleanup removes file and UUID parent directory")
    func cleanup() throws {
        let service = FileActionService()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("test.jpg")
        try Data("stub".utf8).write(to: file)

        #expect(FileManager.default.fileExists(atPath: dir.path))
        service.cleanup(url: file)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("download each call uses a unique temp directory")
    func downloadUsesUniqueDirectory() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: makeURL(),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("a".utf8))
        }

        let service = FileActionService(session: makeSession())
        let url1 = try await service.download(presignedURL: makeURL(), fileName: "a.jpg")
        let url2 = try await service.download(presignedURL: makeURL(), fileName: "a.jpg")
        defer {
            service.cleanup(url: url1)
            service.cleanup(url: url2)
        }

        #expect(url1.deletingLastPathComponent() != url2.deletingLastPathComponent())
    }

    @Test("isDownloading is true during download and false after")
    func isDownloadingState() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: makeURL(),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("x".utf8))
        }

        let service = FileActionService(session: makeSession())
        #expect(!service.isDownloading)
        let local = try await service.download(presignedURL: makeURL(), fileName: "file.txt")
        service.cleanup(url: local)
        #expect(!service.isDownloading)
    }
}
