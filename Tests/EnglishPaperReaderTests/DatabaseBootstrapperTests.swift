import Foundation
import SQLite3
import Testing
@testable import EnglishPaperReader

struct DatabaseBootstrapperTests {
    @Test
    func createsSchemaForFreshDatabase() throws {
        let root = try temporaryDirectory()
        let paths = try AppPaths(baseDirectory: root)

        let result = try DatabaseBootstrapper(paths: paths).prepareDatabase()
        #expect(result.message == "Created a new empty database.")
        #expect(FileManager.default.fileExists(atPath: paths.databaseURL.path))

        let database = try SQLiteDatabase(path: paths.databaseURL.path)
        let tables = try database.query(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            ORDER BY name;
            """
        ) { statement in
            sqliteText(statement, index: 0) ?? ""
        }

        #expect(tables.contains("folders"))
        #expect(tables.contains("pdfs"))
        #expect(tables.contains("words"))
        #expect(tables.contains("meanings"))
        #expect(tables.contains("examples"))
        #expect(tables.contains("appearances"))
    }

    @Test
    func restoresDatabaseFromBackupFile() throws {
        let root = try temporaryDirectory()
        let paths = try AppPaths(baseDirectory: root)
        try paths.ensureDirectoriesExist()

        let backupSQL = """
        CREATE TABLE folders (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          parent_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
          created_at TEXT NOT NULL
        );
        INSERT INTO folders (id, name, parent_id, created_at)
        VALUES ('folder-1', 'Seminar', NULL, '2026-05-04T00:00:00Z');
        """
        try backupSQL.write(to: paths.backupURL, atomically: true, encoding: .utf8)

        let result = try DatabaseBootstrapper(paths: paths).prepareDatabase()
        #expect(result.message == "Restored database from backup.sql.")

        let database = try SQLiteDatabase(path: paths.databaseURL.path)
        let count = try database.querySingle(
            "SELECT COUNT(*) FROM folders;"
        ) { statement in
            Int(sqlite3_column_int64(statement, 0))
        }
        #expect(count == 1)
    }
}
