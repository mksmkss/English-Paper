import AppKit
import Foundation

struct RepositoryConfigurationStore {
    private struct Configuration: Codable {
        let libraryPath: String?
        let repositoryPath: String?
    }

    private let fileManager = FileManager.default

    func loadLibraryURL() throws -> URL? {
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

    @MainActor
    func promptForLibraryURLIfNeeded() throws -> URL {
        if let existing = try loadLibraryURL() {
            return existing
        }

        let selectedURL = try chooseLibraryURL(startingAt: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true))
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        try saveLibraryURL(selectedURL)
        return selectedURL
    }

    @MainActor
    func chooseLibraryURL(startingAt directoryURL: URL?) throws -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Choose a library folder for PapersApp data. The app stores vocabulary data in `.paperapp` inside this folder."
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directoryURL

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    func saveLibraryURL(_ url: URL) throws {
        try fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true)
        let config = Configuration(libraryPath: url.path, repositoryPath: nil)
        let data = try JSONEncoder().encode(config)
        try data.write(to: configFileURL, options: .atomic)
    }

    private var configDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return appSupport.appendingPathComponent("EnglishPaperReader", isDirectory: true)
    }

    private var configFileURL: URL {
        configDirectoryURL.appendingPathComponent("config.json", isDirectory: false)
    }
}
