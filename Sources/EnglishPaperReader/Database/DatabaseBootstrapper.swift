import Foundation

struct DatabaseBootstrapResult {
    let message: String?
}

struct DatabaseBootstrapper {
    let paths: AppPaths

    func prepareDatabase() throws -> DatabaseBootstrapResult {
        try paths.ensureDirectoriesExist()

        let fileManager = FileManager.default
        let databaseExists = fileManager.fileExists(atPath: paths.databaseURL.path)
        let backupExists = fileManager.fileExists(atPath: paths.backupURL.path)

        if !databaseExists {
            if backupExists {
                try restoreDatabaseFromBackup()
                let database = try SQLiteDatabase(path: paths.databaseURL.path)
                try DatabaseMigrator(database: database).migrate()
                return DatabaseBootstrapResult(message: "Restored database from backup.sql.")
            } else {
                let database = try SQLiteDatabase(path: paths.databaseURL.path)
                try DatabaseMigrator(database: database).migrate()
                return DatabaseBootstrapResult(message: "Created a new empty database.")
            }
        }

        let database = try SQLiteDatabase(path: paths.databaseURL.path)
        try DatabaseMigrator(database: database).migrate()
        return DatabaseBootstrapResult(message: nil)
    }

    private func restoreDatabaseFromBackup() throws {
        let sql = try String(contentsOf: paths.backupURL, encoding: .utf8)
        let database = try SQLiteDatabase(path: paths.databaseURL.path)
        do {
            try database.execute(sql)
        } catch {
            throw AppError.restoreFailed(error.localizedDescription)
        }
    }
}
