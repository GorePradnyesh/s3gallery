import Foundation

protocol S3ServiceProtocol: AnyObject {
    func listBuckets() async throws -> [String]
    func listObjects(bucket: String, prefix: String) async throws -> [S3Item]
    func presignedURL(for item: S3FileItem, ttl: TimeInterval) async throws -> URL
}

enum S3ServiceError: Error, LocalizedError {
    case presignFailed
    case invalidResponse
    case unauthorized
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .presignFailed:
            return "Failed to generate presigned URL."
        case .invalidResponse:
            return "Received an invalid response from S3."
        case .unauthorized:
            return "Invalid credentials or insufficient permissions."
        case .notFound(let key):
            return "Object not found: \(key)"
        }
    }
}
