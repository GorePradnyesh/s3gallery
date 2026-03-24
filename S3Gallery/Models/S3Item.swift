import Foundation

enum S3Item: Identifiable, Hashable {
    case folder(name: String, prefix: String)
    case file(S3FileItem)

    var id: String {
        switch self {
        case .folder(_, let prefix): return "folder:\(prefix)"
        case .file(let item): return "file:\(item.key)"
        }
    }

    var name: String {
        switch self {
        case .folder(let name, _): return name
        case .file(let item): return item.name
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    var fileItem: S3FileItem? {
        if case .file(let item) = self { return item }
        return nil
    }
}

struct S3FileItem: Identifiable, Hashable, Codable {
    let key: String
    let bucket: String
    let size: Int64
    let lastModified: Date
    let eTag: String?

    var id: String { "\(bucket)/\(key)" }

    var name: String {
        key.split(separator: "/").last.map(String.init) ?? key
    }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
