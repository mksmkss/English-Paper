import Foundation

struct PDFRecord: Equatable, Sendable, TimestampedRecord {
    let id: String
    var absolutePath: String?
    var filename: String
    var title: String?
    var folderID: String?
    let addedAt: String

    var isMissing: Bool {
        absolutePath == nil
    }
}
