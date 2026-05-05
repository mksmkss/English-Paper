import Foundation
import SQLite3

struct PDFRepository {
    let database: SQLiteDatabase

    func fetchAll() throws -> [PDFRecord] {
        try database.query(
            """
            SELECT id, abs_path, filename, title, folder_id, added_at
            FROM pdfs
            ORDER BY filename COLLATE NOCASE ASC;
            """
        ) { statement in
            PDFRecord(
                id: sqliteText(statement, index: 0) ?? "",
                absolutePath: sqliteText(statement, index: 1),
                filename: sqliteText(statement, index: 2) ?? "",
                title: sqliteText(statement, index: 3),
                folderID: sqliteText(statement, index: 4),
                addedAt: sqliteText(statement, index: 5) ?? ""
            )
        }
    }

    func fetch(id: String) throws -> PDFRecord? {
        try database.querySingle(
            """
            SELECT id, abs_path, filename, title, folder_id, added_at
            FROM pdfs
            WHERE id = ?;
            """,
            bindings: [.text(id)]
        ) { statement in
            PDFRecord(
                id: sqliteText(statement, index: 0) ?? "",
                absolutePath: sqliteText(statement, index: 1),
                filename: sqliteText(statement, index: 2) ?? "",
                title: sqliteText(statement, index: 3),
                folderID: sqliteText(statement, index: 4),
                addedAt: sqliteText(statement, index: 5) ?? ""
            )
        }
    }

    func insert(_ pdf: PDFRecord) throws {
        try database.run(
            """
            INSERT INTO pdfs (id, abs_path, filename, title, folder_id, added_at)
            VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(pdf.id),
                pdf.absolutePath.map(SQLiteValue.text) ?? .null,
                .text(pdf.filename),
                pdf.title.map(SQLiteValue.text) ?? .null,
                pdf.folderID.map(SQLiteValue.text) ?? .null,
                .text(pdf.addedAt)
            ]
        )
    }

    func update(_ pdf: PDFRecord) throws {
        try database.run(
            """
            UPDATE pdfs
            SET abs_path = ?, filename = ?, title = ?, folder_id = ?
            WHERE id = ?;
            """,
            bindings: [
                pdf.absolutePath.map(SQLiteValue.text) ?? .null,
                .text(pdf.filename),
                pdf.title.map(SQLiteValue.text) ?? .null,
                pdf.folderID.map(SQLiteValue.text) ?? .null,
                .text(pdf.id)
            ]
        )
    }

    func updatePath(id: String, absolutePath: String?) throws {
        try database.run(
            "UPDATE pdfs SET abs_path = ? WHERE id = ?;",
            bindings: [
                absolutePath.map(SQLiteValue.text) ?? .null,
                .text(id)
            ]
        )
    }

    func delete(id: String) throws {
        try database.run("DELETE FROM pdfs WHERE id = ?;", bindings: [.text(id)])
    }

    func register(fileURL: URL, folderID: String? = nil, title: String? = nil) throws -> PDFRecord {
        guard fileURL.pathExtension.lowercased() == "pdf" else {
            throw AppError.invalidPDFFile(fileURL)
        }

        let documentID = try PDFHasher.makeDocumentID(for: fileURL)
        let record = PDFRecord(
            id: documentID,
            absolutePath: fileURL.path,
            filename: fileURL.lastPathComponent,
            title: title,
            folderID: folderID,
            addedAt: DateFormatting.iso8601String()
        )

        try database.run(
            """
            INSERT INTO pdfs (id, abs_path, filename, title, folder_id, added_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              abs_path = excluded.abs_path,
              filename = excluded.filename,
              title = COALESCE(excluded.title, pdfs.title),
              folder_id = COALESCE(excluded.folder_id, pdfs.folder_id);
            """,
            bindings: [
                .text(record.id),
                .text(record.absolutePath ?? ""),
                .text(record.filename),
                record.title.map(SQLiteValue.text) ?? .null,
                record.folderID.map(SQLiteValue.text) ?? .null,
                .text(record.addedAt)
            ]
        )

        return try fetch(id: record.id) ?? record
    }

    func markMissingFiles() throws {
        let records = try fetchAll()
        for record in records {
            guard let path = record.absolutePath else { continue }
            if !FileManager.default.fileExists(atPath: path) {
                try updatePath(id: record.id, absolutePath: nil)
            }
        }
    }

    func relink(id: String, to fileURL: URL) throws {
        let expectedID = id
        let actualID = try PDFHasher.makeDocumentID(for: fileURL)
        guard expectedID == actualID else {
            throw AppError.invalidPDFFile(fileURL)
        }
        try updatePath(id: id, absolutePath: fileURL.path)
    }
}
