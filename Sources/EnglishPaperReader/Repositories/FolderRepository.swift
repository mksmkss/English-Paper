import Foundation
import SQLite3

struct FolderRepository {
    let database: SQLiteDatabase

    func fetchAll() throws -> [Folder] {
        try database.query(
            """
            SELECT id, name, parent_id, created_at
            FROM folders
            ORDER BY name COLLATE NOCASE ASC;
            """
        ) { statement in
            Folder(
                id: sqliteText(statement, index: 0) ?? "",
                name: sqliteText(statement, index: 1) ?? "",
                parentID: sqliteText(statement, index: 2),
                createdAt: sqliteText(statement, index: 3) ?? ""
            )
        }
    }

    func fetch(id: String) throws -> Folder? {
        try database.querySingle(
            """
            SELECT id, name, parent_id, created_at
            FROM folders
            WHERE id = ?;
            """,
            bindings: [.text(id)]
        ) { statement in
            Folder(
                id: sqliteText(statement, index: 0) ?? "",
                name: sqliteText(statement, index: 1) ?? "",
                parentID: sqliteText(statement, index: 2),
                createdAt: sqliteText(statement, index: 3) ?? ""
            )
        }
    }

    func insert(_ folder: Folder) throws {
        try database.run(
            """
            INSERT INTO folders (id, name, parent_id, created_at)
            VALUES (?, ?, ?, ?);
            """,
            bindings: [
                .text(folder.id),
                .text(folder.name),
                folder.parentID.map(SQLiteValue.text) ?? .null,
                .text(folder.createdAt)
            ]
        )
    }

    func update(_ folder: Folder) throws {
        try database.run(
            """
            UPDATE folders
            SET name = ?, parent_id = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(folder.name),
                folder.parentID.map(SQLiteValue.text) ?? .null,
                .text(folder.id)
            ]
        )
    }

    func delete(id: String) throws {
        try database.run("DELETE FROM folders WHERE id = ?;", bindings: [.text(id)])
    }
}
