import Foundation
import SQLite3

struct AppearanceRepository {
    let database: SQLiteDatabase

    func fetchAll(wordID: String) throws -> [Appearance] {
        try database.query(
            """
            SELECT id, word_id, meaning_id, pdf_id, page, bbox_x, bbox_y, bbox_width, bbox_height, context_snippet, added_at
            FROM appearances
            WHERE word_id = ?
            ORDER BY added_at DESC;
            """,
            bindings: [.text(wordID)]
        ) { statement in
            Appearance(
                id: sqliteText(statement, index: 0) ?? "",
                wordID: sqliteText(statement, index: 1) ?? "",
                meaningID: sqliteText(statement, index: 2),
                pdfID: sqliteText(statement, index: 3) ?? "",
                page: Int(sqlite3_column_int64(statement, 4)),
                bboxX: sqlite3_column_double(statement, 5),
                bboxY: sqlite3_column_double(statement, 6),
                bboxWidth: sqlite3_column_double(statement, 7),
                bboxHeight: sqlite3_column_double(statement, 8),
                contextSnippet: sqliteText(statement, index: 9),
                addedAt: sqliteText(statement, index: 10) ?? ""
            )
        }
    }

    func fetchAll(pdfID: String) throws -> [Appearance] {
        try database.query(
            """
            SELECT id, word_id, meaning_id, pdf_id, page, bbox_x, bbox_y, bbox_width, bbox_height, context_snippet, added_at
            FROM appearances
            WHERE pdf_id = ?
            ORDER BY page ASC, added_at DESC;
            """,
            bindings: [.text(pdfID)]
        ) { statement in
            Appearance(
                id: sqliteText(statement, index: 0) ?? "",
                wordID: sqliteText(statement, index: 1) ?? "",
                meaningID: sqliteText(statement, index: 2),
                pdfID: sqliteText(statement, index: 3) ?? "",
                page: Int(sqlite3_column_int64(statement, 4)),
                bboxX: sqlite3_column_double(statement, 5),
                bboxY: sqlite3_column_double(statement, 6),
                bboxWidth: sqlite3_column_double(statement, 7),
                bboxHeight: sqlite3_column_double(statement, 8),
                contextSnippet: sqliteText(statement, index: 9),
                addedAt: sqliteText(statement, index: 10) ?? ""
            )
        }
    }

    func fetch(id: String) throws -> Appearance? {
        try database.querySingle(
            """
            SELECT id, word_id, meaning_id, pdf_id, page, bbox_x, bbox_y, bbox_width, bbox_height, context_snippet, added_at
            FROM appearances
            WHERE id = ?;
            """,
            bindings: [.text(id)]
        ) { statement in
            Appearance(
                id: sqliteText(statement, index: 0) ?? "",
                wordID: sqliteText(statement, index: 1) ?? "",
                meaningID: sqliteText(statement, index: 2),
                pdfID: sqliteText(statement, index: 3) ?? "",
                page: Int(sqlite3_column_int64(statement, 4)),
                bboxX: sqlite3_column_double(statement, 5),
                bboxY: sqlite3_column_double(statement, 6),
                bboxWidth: sqlite3_column_double(statement, 7),
                bboxHeight: sqlite3_column_double(statement, 8),
                contextSnippet: sqliteText(statement, index: 9),
                addedAt: sqliteText(statement, index: 10) ?? ""
            )
        }
    }

    func insert(_ appearance: Appearance) throws {
        try database.run(
            """
            INSERT INTO appearances (
              id, word_id, meaning_id, pdf_id, page,
              bbox_x, bbox_y, bbox_width, bbox_height,
              context_snippet, added_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(appearance.id),
                .text(appearance.wordID),
                appearance.meaningID.map(SQLiteValue.text) ?? .null,
                .text(appearance.pdfID),
                .integer(Int64(appearance.page)),
                .double(appearance.bboxX),
                .double(appearance.bboxY),
                .double(appearance.bboxWidth),
                .double(appearance.bboxHeight),
                appearance.contextSnippet.map(SQLiteValue.text) ?? .null,
                .text(appearance.addedAt)
            ]
        )
    }

    func update(_ appearance: Appearance) throws {
        try database.run(
            """
            UPDATE appearances
            SET meaning_id = ?, page = ?, bbox_x = ?, bbox_y = ?, bbox_width = ?, bbox_height = ?, context_snippet = ?
            WHERE id = ?;
            """,
            bindings: [
                appearance.meaningID.map(SQLiteValue.text) ?? .null,
                .integer(Int64(appearance.page)),
                .double(appearance.bboxX),
                .double(appearance.bboxY),
                .double(appearance.bboxWidth),
                .double(appearance.bboxHeight),
                appearance.contextSnippet.map(SQLiteValue.text) ?? .null,
                .text(appearance.id)
            ]
        )
    }

    func delete(id: String) throws {
        try database.run("DELETE FROM appearances WHERE id = ?;", bindings: [.text(id)])
    }

    func insertAndRefreshCount(_ appearance: Appearance, wordRepository: WordRepository) throws {
        try database.performTransaction {
            try insert(appearance)
            try wordRepository.refreshTotalCount(wordID: appearance.wordID)
        }
    }
}
