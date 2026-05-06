import Foundation

struct AppPaths {
    let baseDirectory: URL
    let storageDirectory: URL
    let syncDirectory: URL
    let databaseURL: URL
    let backupURL: URL

    @MainActor
    static func `default`() throws -> AppPaths {
        let environment = ProcessInfo.processInfo.environment

        if let configured = environment["PAPERAPP_BASE_DIR"], !configured.isEmpty {
            return try AppPaths(baseDirectory: URL(fileURLWithPath: configured, isDirectory: true))
        }

        let store = RepositoryConfigurationStore()
        let defaultStorageURL = store.defaultStorageURL()

        if let legacyURL = try store.loadLegacyLibraryURL() {
            try store.migrateLegacyStorageIfNeeded(from: legacyURL, to: defaultStorageURL)
            try? store.clearLegacyLibraryURL()
        }

        return try AppPaths(baseDirectory: defaultStorageURL)
    }

    init(baseDirectory: URL) throws {
        self.baseDirectory = baseDirectory.standardizedFileURL
        self.storageDirectory = self.baseDirectory
        self.syncDirectory = self.storageDirectory
        self.databaseURL = storageDirectory.appendingPathComponent("app.db", isDirectory: false)
        self.backupURL = storageDirectory.appendingPathComponent("backup.sql", isDirectory: false)
    }

    func ensureDirectoriesExist() throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }
}
