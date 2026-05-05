import Foundation

struct Meaning: Equatable, Sendable, TimestampedRecord {
    let id: String
    let wordID: String
    var pos: String?
    var definition: String
    var note: String?
    var sortOrder: Int
}
