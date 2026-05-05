import Foundation

struct Word: Equatable, Sendable, TimestampedRecord {
    let id: String
    var surface: String
    var reading: String?
    var totalCount: Int
    let addedAt: String
}
