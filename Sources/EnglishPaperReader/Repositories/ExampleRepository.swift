import Foundation
import SQLite3

struct ExampleRepository {
    let database: SQLiteDatabase

    func fetchAll(meaningID: String) throws -> [Example] {
        try database.query(
            """
            SELECT id, meaning_id, en, ja, source_pdf_id, sort_order
            FROM examples
            WHERE meaning_id = ?
            ORDER BY sort_order ASC, rowid ASC;
            """,
            bindings: [.text(meaningID)]
        ) { statement in
            Example(
                id: sqliteText(statement, index: 0) ?? "",
                meaningID: sqliteText(statement, index: 1) ?? "",
                en: sqliteText(statement, index: 2) ?? "",
                ja: sqliteText(statement, index: 3),
                sourcePDFID: sqliteText(statement, index: 4),
                sortOrder: Int(sqlite3_column_int64(statement, 5))
            )
        }
    }

    func fetch(id: String) throws -> Example? {
        try database.querySingle(
            """
            SELECT id, meaning_id, en, ja, source_pdf_id, sort_order
            FROM examples
            WHERE id = ?;
            """,
            bindings: [.text(id)]
        ) { statement in
            Example(
                id: sqliteText(statement, index: 0) ?? "",
                meaningID: sqliteText(statement, index: 1) ?? "",
                en: sqliteText(statement, index: 2) ?? "",
                ja: sqliteText(statement, index: 3),
                sourcePDFID: sqliteText(statement, index: 4),
                sortOrder: Int(sqlite3_column_int64(statement, 5))
            )
        }
    }

    func insert(_ example: Example) throws {
        try database.run(
            """
            INSERT INTO examples (id, meaning_id, en, ja, source_pdf_id, sort_order)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(example.id),
                .text(example.meaningID),
                .text(example.en),
                example.ja.map(SQLiteValue.text) ?? .null,
                example.sourcePDFID.map(SQLiteValue.text) ?? .null,
                .integer(Int64(example.sortOrder))
            ]
        )
    }

    func update(_ example: Example) throws {
        try database.run(
            """
            UPDATE examples
            SET en = ?, ja = ?, source_pdf_id = ?, sort_order = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(example.en),
                example.ja.map(SQLiteValue.text) ?? .null,
                example.sourcePDFID.map(SQLiteValue.text) ?? .null,
                .integer(Int64(example.sortOrder)),
                .text(example.id)
            ]
        )
    }

    func delete(id: String) throws {
        try database.run("DELETE FROM examples WHERE id = ?;", bindings: [.text(id)])
    }
}
