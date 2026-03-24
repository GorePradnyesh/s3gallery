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

            // Contents become file items (skip the prefix placeholder itself)
            let files: [S3Item] = output.contents?.compactMap { obj -> S3Item? in
                guard let key = obj.key, key != prefix, !key.hasSuffix("/") else { return nil }
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
}
