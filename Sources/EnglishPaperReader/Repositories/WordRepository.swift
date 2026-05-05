import Foundation
import SQLite3

enum WordSort: Hashable {
    case difficultyDescending
    case addedAtDescending
}

struct WordRepository {
    let database: SQLiteDatabase

    func fetchAll(sortedBy sort: WordSort = .difficultyDescending) throws -> [Word] {
        let orderBy: String
        switch sort {
        case .difficultyDescending:
            orderBy = "ORDER BY total_count DESC, added_at DESC"
        case .addedAtDescending:
            orderBy = "ORDER BY added_at DESC"
        }

        return try database.query(
            """
            SELECT id, surface, reading, total_count, added_at
            FROM words
            \(orderBy);
            """
        ) { statement in
            Word(
                id: sqliteText(statement, index: 0) ?? "",
                surface: sqliteText(statement, index: 1) ?? "",
                reading: sqliteText(statement, index: 2),
                totalCount: Int(sqlite3_column_int64(statement, 3)),
                addedAt: sqliteText(statement, index: 4) ?? ""
            )
        }
    }

    func fetch(id: String) throws -> Word? {
        try database.querySingle(
            """
            SELECT id, surface, reading, total_count, added_at
            FROM words
            WHERE id = ?;
            """,
            bindings: [.text(id)]
        ) { statement in
            Word(
                id: sqliteText(statement, index: 0) ?? "",
                surface: sqliteText(statement, index: 1) ?? "",
                reading: sqliteText(statement, index: 2),
                totalCount: Int(sqlite3_column_int64(statement, 3)),
                addedAt: sqliteText(statement, index: 4) ?? ""
            )
        }
    }

    func fetchBySurface(_ surface: String) throws -> Word? {
        try database.querySingle(
            """
            SELECT id, surface, reading, total_count, added_at
            FROM words
            WHERE lower(surface) = lower(?)
            LIMIT 1;
            """,
            bindings: [.text(surface)]
        ) { statement in
            Word(
                id: sqliteText(statement, index: 0) ?? "",
                surface: sqliteText(statement, index: 1) ?? "",
                reading: sqliteText(statement, index: 2),
                totalCount: Int(sqlite3_column_int64(statement, 3)),
                addedAt: sqliteText(statement, index: 4) ?? ""
            )
        }
    }

    func insert(_ word: Word) throws {
        try database.run(
            """
            INSERT INTO words (id, surface, reading, total_count, added_at)
            VALUES (?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(word.id),
                .text(word.surface),
                word.reading.map(SQLiteValue.text) ?? .null,
                .integer(Int64(word.totalCount)),
                .text(word.addedAt)
            ]
        )
    }

    func upsert(surface: String, reading: String?) throws -> Word {
        if var existing = try fetchBySurface(surface) {
            if let reading, !reading.isEmpty, existing.reading != reading {
                existing.reading = reading
                try update(existing)
            }
            return existing
        }

        let word = Word(
            id: UUID().uuidString.lowercased(),
            surface: surface,
            reading: reading,
            totalCount: 0,
            addedAt: DateFormatting.iso8601String()
        )
        try insert(word)
        return word
    }

    func update(_ word: Word) throws {
        try database.run(
            """
            UPDATE words
            SET surface = ?, reading = ?, total_count = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(word.surface),
                word.reading.map(SQLiteValue.text) ?? .null,
                .integer(Int64(word.totalCount)),
                .text(word.id)
            ]
        )
    }

    func updateTotalCount(wordID: String, totalCount: Int) throws {
        try database.run(
            "UPDATE words SET total_count = ? WHERE id = ?;",
            bindings: [.integer(Int64(totalCount)), .text(wordID)]
        )
    }

    func refreshTotalCount(wordID: String) throws {
        let count = try database.querySingle(
            "SELECT COUNT(*) FROM appearances WHERE word_id = ?;",
            bindings: [.text(wordID)]
        ) { statement in
            Int(sqlite3_column_int64(statement, 0))
        } ?? 0

        try updateTotalCount(wordID: wordID, totalCount: count)
    }

    func delete(id: String) throws {
        try database.run("DELETE FROM words WHERE id = ?;", bindings: [.text(id)])
    }
}
