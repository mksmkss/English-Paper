import AppKit
import Foundation
import UniformTypeIdentifiers

enum AppOpenPanel {
    @MainActor
    static func choosePDF() throws -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
