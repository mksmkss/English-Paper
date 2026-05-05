import Foundation
import SQLite3

final class SQLiteDatabase {
    private let handle: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        if sqlite3_open(path, &db) != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let db {
                sqlite3_close(db)
            }
            throw AppError.databaseOpenFailed(message)
        }

        guard let db else {
            throw AppError.databaseOpenFailed("SQLite returned a nil handle.")
        }

        self.handle = db
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &errorPointer) != SQLITE_OK {
            let message = errorPointer.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorPointer)
            throw AppError.executionFailed(message)
        }
    }

    func performTransaction(_ block: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try block()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(handle, sql, -1, &statement, nil) != SQLITE_OK {
            throw AppError.statementPreparationFailed(lastErrorMessage())
        }

        guard let statement else {
            throw AppError.statementPreparationFailed("SQLite returned a nil statement.")
        }
        return statement
    }

    func run(_ sql: String, bindings: [SQLiteValue] = []) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        if sqlite3_step(statement) != SQLITE_DONE {
            throw AppError.executionFailed(lastErrorMessage())
        }
    }

    func query<T>(_ sql: String, bindings: [SQLiteValue] = [], map: (OpaquePointer) throws -> T) throws -> [T] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)

        var results: [T] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                results.append(try map(statement))
            } else if stepResult == SQLITE_DONE {
                return results
            } else {
                throw AppError.executionFailed(lastErrorMessage())
            }
        }
    }

    func querySingle<T>(_ sql: String, bindings: [SQLiteValue] = [], map: (OpaquePointer) throws -> T) throws -> T? {
        try query(sql, bindings: bindings, map: map).first
    }

    func lastInsertedRowID() -> Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            let result: Int32

            switch value {
            case .integer(let number):
                result = sqlite3_bind_int64(statement, position, number)
            case .double(let number):
                result = sqlite3_bind_double(statement, position, number)
            case .text(let string):
                result = sqlite3_bind_text(statement, position, string, -1, SQLITE_TRANSIENT)
            case .null:
                result = sqlite3_bind_null(statement, position)
            }

            if result != SQLITE_OK {
                throw AppError.executionFailed(lastErrorMessage())
            }
        }
    }

    private func lastErrorMessage() -> String {
        String(cString: sqlite3_errmsg(handle))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
