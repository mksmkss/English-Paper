import AppKit
import SwiftUI

@MainActor
private final class SettingsSheetModel: ObservableObject {
    @Published var remoteURL = ""
    @Published var isConnected = false
    @Published var isWorking = false
    @Published var alertMessage: String?

    func load(paths: AppPaths) {
        let result = LocalCommandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", paths.syncDirectory.path, "remote", "get-url", "origin"]
        )
        if result.exitCode == 0 {
            remoteURL = result.standardOutput
            isConnected = !result.standardOutput.isEmpty
        } else {
            remoteURL = ""
            isConnected = false
        }
    }

    func saveRemoteURL(paths: AppPaths) async {
        let sanitizedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedURL.isEmpty else {
            alertMessage = "Enter a GitHub repository URL."
            return
        }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let result = await Task.detached(priority: .userInitiated) {
            let repositoryExists = LocalCommandRunner.run(
                "/usr/bin/env",
                arguments: ["git", "-C", paths.syncDirectory.path, "rev-parse", "--show-toplevel"]
            )

            if repositoryExists.exitCode != 0 {
                let initResult = LocalCommandRunner.run(
                    "/usr/bin/env",
                    arguments: ["git", "-C", paths.syncDirectory.path, "init"]
                )
                guard initResult.exitCode == 0 else { return initResult }
            }

            let remoteExists = LocalCommandRunner.run(
                "/usr/bin/env",
                arguments: ["git", "-C", paths.syncDirectory.path, "remote", "get-url", "origin"]
            )

            if remoteExists.exitCode == 0 {
                return LocalCommandRunner.run(
                    "/usr/bin/env",
                    arguments: ["git", "-C", paths.syncDirectory.path, "remote", "set-url", "origin", sanitizedURL]
                )
            } else {
                return LocalCommandRunner.run(
                    "/usr/bin/env",
                    arguments: ["git", "-C", paths.syncDirectory.path, "remote", "add", "origin", sanitizedURL]
                )
            }
        }.value

        if result.exitCode == 0 {
            isConnected = true
            alertMessage = "GitHub remote updated."
        } else {
            let output = [result.standardError, result.standardOutput]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            alertMessage = output.isEmpty ? "Unable to update the GitHub remote." : output
        }
        load(paths: paths)
    }
}

struct SettingsSheet: View {
    let paths: AppPaths
    let onDismiss: () -> Void

    @StateObject private var model = SettingsSheetModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Vocabulary Data") {
                    SettingsValueRow(title: "Storage Folder", value: paths.storageDirectory.path)
                    SettingsValueRow(title: "Database File", value: paths.databaseURL.lastPathComponent)
                    SettingsValueRow(title: "Backup File", value: paths.backupURL.lastPathComponent)

                    HStack {
                        Button("Open Data Folder") {
                            NSWorkspace.shared.open(paths.storageDirectory)
                        }
                        Button("Reveal app.db") {
                            NSWorkspace.shared.selectFile(paths.databaseURL.path, inFileViewerRootedAtPath: paths.storageDirectory.path)
                        }
                        Button("Reveal backup.sql") {
                            NSWorkspace.shared.selectFile(paths.backupURL.path, inFileViewerRootedAtPath: paths.storageDirectory.path)
                        }
                    }
                }

                Section("GitHub Sync") {
                    TextField("https://github.com/owner/repo.git", text: $model.remoteURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(model.isWorking)

                    HStack {
                        Circle()
                            .fill(model.isConnected ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(model.isConnected ? "Connected" : "Not connected")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Save Remote Repository") {
                            Task {
                                await model.saveRemoteURL(paths: paths)
                            }
                        }
                        .disabled(model.isWorking || model.remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if model.isConnected, let remoteURL = URL(string: model.remoteURL) {
                            Button("Open Repository") {
                                NSWorkspace.shared.open(remoteURL)
                            }
                        }
                    }
                }

                Section("Updates") {
                    Text("Check the latest release page to download updates.")
                        .foregroundStyle(.secondary)

                    Button("Check for Updates") {
                        guard let url = URL(string: "https://github.com/mksmkss/English-Paper/releases/latest") else { return }
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 680, height: 430)
        .task {
            model.load(paths: paths)
        }
        .alert("Settings", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK") {
                model.alertMessage = nil
            }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
