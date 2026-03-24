import Foundation

struct Credentials: Codable, Equatable {
    let accessKeyId: String
    let secretAccessKey: String
    let region: String
}
