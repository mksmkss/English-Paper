import Foundation

struct Example: Equatable, Sendable, TimestampedRecord {
    let id: String
    let meaningID: String
    var en: String
    var ja: String?
    var sourcePDFID: String?
    var sortOrder: Int
}
