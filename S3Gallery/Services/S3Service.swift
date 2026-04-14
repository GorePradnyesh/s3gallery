import Foundation
import AWSS3
import AWSClientRuntime
import SmithyIdentity

final class S3Service: S3ServiceProtocol {
    private let client: S3Client
    private let credentials: Credentials

    init(credentials: Credentials) async throws {
        self.credentials = credentials
        let identity = AWSCredentialIdentity(
            accessKey: credentials.accessKeyId,
            secret: credentials.secretAccessKey
        )
        let resolver = try StaticAWSCredentialIdentityResolver(identity)
        let config = try await S3Client.S3ClientConfig(
            awsCredentialIdentityResolver: resolver,
            region: credentials.region
        )
        self.client = S3Client(config: config)
    }

    func listBuckets() async throws -> [String] {
        let output = try await client.listBuckets(input: ListBucketsInput())
        return output.buckets?.compactMap { $0.name } ?? []
    }

    func listObjects(bucket: String, prefix: String) async throws -> [S3Item] {
        var items: [S3Item] = []
        var continuationToken: String?

        repeat {
            let input = ListObjectsV2Input(
                bucket: bucket,
                continuationToken: continuationToken,
                delimiter: "/",
                prefix: prefix.isEmpty ? nil : prefix
            )
            let output = try await client.listObjectsV2(input: input)

            // Common prefixes become folder items
            let folders: [S3Item] = output.commonPrefixes?.compactMap { cp -> S3Item? in
                guard let p = cp.prefix else { return nil }
                let folderName = p.hasSuffix("/")
                    ? String(p.dropLast())
                    : p
                let displayName = folderName.split(separator: "/").last.map(String.init) ?? folderName
                return S3Item.folder(name: displayName, prefix: p)
            } ?? []

            // Contents become file items (skip the prefix placeholder and internal probe files)
            let files: [S3Item] = output.contents?.compactMap { obj -> S3Item? in
                guard let key = obj.key, key != prefix, !key.hasSuffix("/"),
                      !key.hasSuffix(".s3gallery-probe") else { return nil }
                let fileItem = S3FileItem(
                    key: key,
                    bucket: bucket,
                    size: Int64(obj.size ?? 0),
                    lastModified: obj.lastModified ?? Date(),
                    eTag: obj.eTag
                )
                return S3Item.file(fileItem)
            } ?? []

            items += folders + files
            continuationToken = output.isTruncated == true ? output.nextContinuationToken : nil
        } while continuationToken != nil

        return items
    }

    func presignedURL(for item: S3FileItem, ttl: TimeInterval) async throws -> URL {
        let input = GetObjectInput(bucket: item.bucket, key: item.key)
        return try await client.presignedURLForGetObject(input: input, expiration: ttl)
    }

    func checkWriteAccess(bucket: String) async throws -> Bool {
        do {
            _ = try await client.putObject(input: PutObjectInput(
                body: .data(Data()),
                bucket: bucket,
                contentLength: 0,
                key: ".s3gallery-probe"
            ))
            return true
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("network") || msg.contains("offline") || msg.contains("connection") {
                throw error
            }
            return false
        }
    }

    func uploadObject(bucket: String, key: String, data: Data, contentType: String) async throws {
        do {
            _ = try await client.putObject(input: PutObjectInput(
                body: .data(data),
                bucket: bucket,
                contentLength: data.count,
                contentType: contentType,
                key: key
            ))
        } catch {
            throw S3ServiceError.uploadFailed(error.localizedDescription)
        }
    }

    func createFolder(bucket: String, key: String) async throws {
        do {
            _ = try await client.putObject(input: PutObjectInput(
                body: .data(Data()),
                bucket: bucket,
                contentLength: 0,
                contentType: "application/octet-stream",
                key: key
            ))
        } catch {
            throw S3ServiceError.uploadFailed(error.localizedDescription)
        }
    }

    func prefixExists(bucket: String, prefix: String) async throws -> Bool {
        let input = ListObjectsV2Input(
            bucket: bucket,
            delimiter: "/",
            maxKeys: 1,
            prefix: prefix
        )
        let output = try await client.listObjectsV2(input: input)
        return (output.contents?.count ?? 0) > 0 || (output.commonPrefixes?.count ?? 0) > 0
    }

    func copyObject(bucket: String, sourceKey: String, destKey: String) async throws {
        // copySource must be "bucket/key" — percent-encode the key portion for header safety
        let encodedKey = sourceKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sourceKey
        do {
            _ = try await client.copyObject(input: CopyObjectInput(
                bucket: bucket,
                copySource: "\(bucket)/\(encodedKey)",
                key: destKey
            ))
        } catch {
            throw S3ServiceError.copyFailed(error.localizedDescription)
        }
    }

    func deleteObject(bucket: String, key: String) async throws {
        do {
            _ = try await client.deleteObject(input: DeleteObjectInput(bucket: bucket, key: key))
        } catch {
            throw S3ServiceError.deleteFailed(error.localizedDescription)
        }
    }

    func listAllObjects(bucket: String, prefix: String) async throws -> [String] {
        var keys: [String] = []
        var continuationToken: String?

        repeat {
            let input = ListObjectsV2Input(
                bucket: bucket,
                continuationToken: continuationToken,
                prefix: prefix.isEmpty ? nil : prefix
            )
            let output = try await client.listObjectsV2(input: input)
            keys += output.contents?.compactMap { $0.key } ?? []
            continuationToken = output.isTruncated == true ? output.nextContinuationToken : nil
        } while continuationToken != nil

        return keys
    }
}
