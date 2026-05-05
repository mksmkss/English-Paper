import Foundation

enum AppError: LocalizedError {
    case databaseOpenFailed(String)
    case statementPreparationFailed(String)
    case executionFailed(String)
    case restoreFailed(String)
    case invalidPDFFile(URL)

    var errorDescription: String? {
        switch self {
        case .databaseOpenFailed(let message):
            "Failed to open database: \(message)"
        case .statementPreparationFailed(let message):
            "Failed to prepare SQLite statement: \(message)"
        case .executionFailed(let message):
            "SQLite execution failed: \(message)"
        case .restoreFailed(let message):
            "Database restore failed: \(message)"
        case .invalidPDFFile(let url):
            "The selected file is not a valid PDF: \(url.path)"
        }
    }
}
