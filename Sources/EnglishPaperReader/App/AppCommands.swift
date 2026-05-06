import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        SidebarCommands()

        CommandMenu("Library") {
            Button("Add PDF…") {
                NotificationCenter.default.post(name: .requestAddPDFCommand, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("New Folder") {
                NotificationCenter.default.post(name: .requestNewFolderCommand, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Rename Folder") {
                NotificationCenter.default.post(name: .requestRenameSidebarItemCommand, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [])

            Divider()

            Button("Change Library Folder…") {
                NotificationCenter.default.post(name: .changeLibraryFolderCommand, object: nil)
            }
        }

        CommandMenu("View") {
            Button("Show or Hide Word List") {
                NotificationCenter.default.post(name: .toggleWordPanelCommand, object: nil)
            }
            .keyboardShortcut("w", modifiers: [.command, .option])

            Divider()

            Button("Fit PDF to Window") {
                NotificationCenter.default.post(name: .fitPDFToWindowCommand, object: nil)
            }
            .keyboardShortcut("0", modifiers: [.command])

            Button("Zoom In") {
                NotificationCenter.default.post(name: .zoomInPDFCommand, object: nil)
            }
            .keyboardShortcut("=", modifiers: [.command])

            Button("Zoom Out") {
                NotificationCenter.default.post(name: .zoomOutPDFCommand, object: nil)
            }
            .keyboardShortcut("-", modifiers: [.command])
        }
    }
}
