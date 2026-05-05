import Foundation

struct Folder: Equatable, Sendable, TimestampedRecord {
    let id: String
    var name: String
    var parentID: String?
    let createdAt: String
}
