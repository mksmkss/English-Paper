import Foundation

struct Appearance: Equatable, Sendable, TimestampedRecord {
    let id: String
    let wordID: String
    var meaningID: String?
    let pdfID: String
    var page: Int
    var bboxX: Double
    var bboxY: Double
    var bboxWidth: Double
    var bboxHeight: Double
    var contextSnippet: String?
    let addedAt: String
}
