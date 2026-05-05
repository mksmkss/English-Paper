import Foundation

struct AppPaths {
    let baseDirectory: URL
    let storageDirectory: URL
    let databaseURL: URL
    let backupURL: URL

    @MainActor
    static func `default`() throws -> AppPaths {
        let environment = ProcessInfo.processInfo.environment

        if let configured = environment["PAPERAPP_BASE_DIR"], !configured.isEmpty {
            return try AppPaths(baseDirectory: URL(fileURLWithPath: configured, isDirectory: true))
        }

        if let storedURL = try RepositoryConfigurationStore().loadRepositoryURL() {
            return try AppPaths(baseDirectory: storedURL)
        }

        let chosenURL = try RepositoryConfigurationStore().promptForRepositoryURLIfNeeded()
        return try AppPaths(baseDirectory: chosenURL)
    }

    init(baseDirectory: URL) throws {
        self.baseDirectory = baseDirectory.standardizedFileURL
        self.storageDirectory = self.baseDirectory.appendingPathComponent(".paperapp", isDirectory: true)
        self.databaseURL = storageDirectory.appendingPathComponent("app.db", isDirectory: false)
        self.backupURL = storageDirectory.appendingPathComponent("backup.sql", isDirectory: false)
    }

    func ensureDirectoriesExist() throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }
}
