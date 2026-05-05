import Foundation

enum SQLiteValue {
    case integer(Int64)
    case double(Double)
    case text(String)
    case null
}
