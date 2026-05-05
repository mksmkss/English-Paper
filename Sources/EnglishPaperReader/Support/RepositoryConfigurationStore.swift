import AppKit
import Foundation

struct RepositoryConfigurationStore {
    private struct Configuration: Codable {
        let repositoryPath: String
    }

    private let fileManager = FileManager.default

    func loadRepositoryURL() throws -> URL? {
        guard fileManager.fileExists(atPath: configFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: configFileURL)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        return URL(fileURLWithPath: config.repositoryPath, isDirectory: true)
    }

    @MainActor
    func promptForRepositoryURLIfNeeded() throws -> URL {
        if let existing = try loadRepositoryURL() {
            return existing
        }

        let panel = NSOpenPanel()
        panel.message = "Choose the repository folder to store .paperapp data."
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let selectedURL: URL
        if panel.runModal() == .OK, let url = panel.url {
            selectedURL = url
        } else {
            selectedURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        }

        try saveRepositoryURL(selectedURL)
        return selectedURL
    }

    func saveRepositoryURL(_ url: URL) throws {
        try fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true)
        let config = Configuration(repositoryPath: url.path)
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
