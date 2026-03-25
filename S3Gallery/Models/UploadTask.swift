import Foundation

struct UploadTask: Identifiable {
    let id: UUID
    let filename: String
    let data: Data
    let contentType: String
    var state: UploadTaskState

    init(filename: String, data: Data, contentType: String) {
        self.id = UUID()
        self.filename = filename
        self.data = data
        self.contentType = contentType
        self.state = .pending
    }
}

enum UploadTaskState {
    case pending
    case uploading
    case success(S3FileItem)
    case failure(Error)
}
