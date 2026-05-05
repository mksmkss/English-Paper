import Foundation
import SQLite3

func sqliteText(_ statement: OpaquePointer, index: Int32) -> String? {
    guard let cString = sqlite3_column_text(statement, index) else {
        return nil
    }
    return String(cString: cString)
}
