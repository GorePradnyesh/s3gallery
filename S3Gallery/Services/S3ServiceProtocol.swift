import Foundation

protocol S3ServiceProtocol: AnyObject {
    func listBuckets() async throws -> [String]
    func listObjects(bucket: String, prefix: String) async throws -> [S3Item]
    func presignedURL(for item: S3FileItem, ttl: TimeInterval) async throws -> URL
    func checkWriteAccess(bucket: String) async throws -> Bool
    func uploadObject(bucket: String, key: String, data: Data, contentType: String) async throws
    func createFolder(bucket: String, key: String) async throws
    func prefixExists(bucket: String, prefix: String) async throws -> Bool
}

enum S3ServiceError: Error, LocalizedError {
    case presignFailed
    case invalidResponse
    case unauthorized
    case notFound(String)
    case uploadFailed(String)
    case folderAlreadyExists

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
        case .uploadFailed(let detail):
            return "Upload failed: \(detail)"
        case .folderAlreadyExists:
            return "A folder with this name already exists."
        }
    }
}
