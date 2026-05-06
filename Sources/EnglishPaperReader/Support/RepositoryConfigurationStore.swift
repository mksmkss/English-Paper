import Foundation

struct RepositoryConfigurationStore {
    private struct Configuration: Codable {
        let libraryPath: String?
        let repositoryPath: String?
    }

    private let fileManager = FileManager.default

    func defaultStorageURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("EnglishPaperReader", isDirectory: true)
    }

    func loadLegacyLibraryURL() throws -> URL? {
        guard fileManager.fileExists(atPath: configFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: configFileURL)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        let resolvedPath = config.libraryPath ?? config.repositoryPath
        guard let resolvedPath, !resolvedPath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: resolvedPath, isDirectory: true)
    }

    func migrateLegacyStorageIfNeeded(from legacyBaseURL: URL, to destinationBaseURL: URL) throws {
        let destinationStorageURL = destinationBaseURL.standardizedFileURL
        let legacyCandidates = [
            legacyBaseURL.standardizedFileURL.appendingPathComponent(".paperapp", isDirectory: true),
            legacyBaseURL.standardizedFileURL
        ]

        guard let sourceStorageURL = legacyCandidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return
        }

        try fileManager.createDirectory(at: destinationStorageURL, withIntermediateDirectories: true)

        for filename in ["app.db", "backup.sql"] {
            let sourceURL = sourceStorageURL.appendingPathComponent(filename, isDirectory: false)
            let destinationURL = destinationStorageURL.appendingPathComponent(filename, isDirectory: false)
            guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    func clearLegacyLibraryURL() throws {
        guard fileManager.fileExists(atPath: configFileURL.path) else {
            return
        }
        try fileManager.removeItem(at: configFileURL)
    }

    private var configDirectoryURL: URL {
        defaultStorageURL()
    }

    private var configFileURL: URL {
        configDirectoryURL.appendingPathComponent("config.json", isDirectory: false)
    }
}
