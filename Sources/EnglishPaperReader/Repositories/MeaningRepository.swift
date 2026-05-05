import Foundation
import SQLite3

struct MeaningRepository {
    let database: SQLiteDatabase

    func fetchAll(wordID: String) throws -> [Meaning] {
        try database.query(
            """
            SELECT id, word_id, pos, definition, note, sort_order
            FROM meanings
            WHERE word_id = ?
            ORDER BY sort_order ASC, rowid ASC;
            """,
            bindings: [.text(wordID)]
        ) { statement in
            Meaning(
                id: sqliteText(statement, index: 0) ?? "",
                wordID: sqliteText(statement, index: 1) ?? "",
                pos: sqliteText(statement, index: 2),
                definition: sqliteText(statement, index: 3) ?? "",
                note: sqliteText(statement, index: 4),
                sortOrder: Int(sqlite3_column_int64(statement, 5))
            )
        }
    }

    func fetch(id: String) throws -> Meaning? {
        try database.querySingle(
            """
            SELECT id, word_id, pos, definition, note, sort_order
            FROM meanings
            WHERE id = ?;
            """,
            bindings: [.text(id)]
        ) { statement in
            Meaning(
                id: sqliteText(statement, index: 0) ?? "",
                wordID: sqliteText(statement, index: 1) ?? "",
                pos: sqliteText(statement, index: 2),
                definition: sqliteText(statement, index: 3) ?? "",
                note: sqliteText(statement, index: 4),
                sortOrder: Int(sqlite3_column_int64(statement, 5))
            )
        }
    }

    func insert(_ meaning: Meaning) throws {
        try database.run(
            """
            INSERT INTO meanings (id, word_id, pos, definition, note, sort_order)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(meaning.id),
                .text(meaning.wordID),
                meaning.pos.map(SQLiteValue.text) ?? .null,
                .text(meaning.definition),
                meaning.note.map(SQLiteValue.text) ?? .null,
                .integer(Int64(meaning.sortOrder))
            ]
        )
    }

    func update(_ meaning: Meaning) throws {
        try database.run(
            """
            UPDATE meanings
            SET pos = ?, definition = ?, note = ?, sort_order = ?
            WHERE id = ?;
            """,
            bindings: [
                meaning.pos.map(SQLiteValue.text) ?? .null,
                .text(meaning.definition),
                meaning.note.map(SQLiteValue.text) ?? .null,
                .integer(Int64(meaning.sortOrder)),
                .text(meaning.id)
            ]
        )
    }

    func delete(id: String) throws {
        try database.run("DELETE FROM meanings WHERE id = ?;", bindings: [.text(id)])
    }
}
