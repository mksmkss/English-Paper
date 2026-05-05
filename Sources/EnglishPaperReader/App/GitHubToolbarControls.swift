import SwiftUI

private enum GitHubConnectionState: Equatable {
    case disconnected
    case connected(remoteURL: String, isDirty: Bool)

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }

    var remoteURL: String? {
        switch self {
        case .disconnected:
            return nil
        case .connected(let remoteURL, _):
            return remoteURL
        }
    }

    var statusLabel: String {
        switch self {
        case .disconnected:
            return "Connect this project to GitHub"
        case .connected(_, let isDirty):
            return isDirty ? "GitHub connected, changes ready to commit" : "GitHub connected"
        }
    }

    var statusIconName: String {
        switch self {
        case .disconnected:
            return "point.3.connected.trianglepath.dotted"
        case .connected(_, let isDirty):
            return isDirty ? "arrow.trianglehead.2.clockwise.rotate.90.circle.fill" : "checkmark.circle.fill"
        }
    }

    var statusColor: Color {
        switch self {
        case .disconnected:
            return .secondary
        case .connected(_, let isDirty):
            return isDirty ? .orange : .green
        }
    }
}

private struct GitHubConnectDraft: Identifiable {
    let id = UUID()
    var remoteURL: String
}

private struct GitCommitDraft: Identifiable {
    let id = UUID()
    var message: String
}

@MainActor
private final class GitHubToolbarModel: ObservableObject {
    @Published var state: GitHubConnectionState = .disconnected
    @Published var isWorking = false
    @Published var alertMessage: String?
    @Published var connectDraft: GitHubConnectDraft?
    @Published var commitDraft: GitCommitDraft?

    func refresh(baseDirectory: URL) async {
        let result = await Task.detached(priority: .utility) {
            GitHubToolbarModel.resolveGitHubState(baseDirectory: baseDirectory)
        }.value
        state = result
    }

    func beginConnect() {
        connectDraft = GitHubConnectDraft(remoteURL: state.remoteURL ?? "")
    }

    func beginCommit() {
        commitDraft = GitCommitDraft(message: "")
    }

    func connect(baseDirectory: URL, remoteURL: String) async {
        let sanitizedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedURL.isEmpty else {
            alertMessage = "Enter a GitHub repository URL."
            return
        }

        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let result = await Task.detached(priority: .userInitiated) {
            GitHubToolbarModel.connectAndPush(baseDirectory: baseDirectory, remoteURL: sanitizedURL)
        }.value

        connectDraft = nil
        await handle(result: result, successMessage: "GitHub connection completed.", baseDirectory: baseDirectory)
    }

    func commitAndPush(baseDirectory: URL, message: String) async {
        let sanitizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedMessage.isEmpty else {
            alertMessage = "Enter a commit message."
            return
        }

        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let result = await Task.detached(priority: .userInitiated) {
            GitHubToolbarModel.commitAndPush(baseDirectory: baseDirectory, message: sanitizedMessage)
        }.value

        commitDraft = nil
        await handle(result: result, successMessage: "Push completed successfully.", baseDirectory: baseDirectory)
    }

    private func handle(result: LocalCommandResult, successMessage: String, baseDirectory: URL) async {
        if result.exitCode == 0 {
            let output = [result.standardOutput, result.standardError]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            alertMessage = output.isEmpty ? successMessage : output
            await refresh(baseDirectory: baseDirectory)
        } else {
            let output = [result.standardError, result.standardOutput]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            alertMessage = output.isEmpty ? "GitHub action failed." : output
        }
    }

    nonisolated private static func resolveGitHubState(baseDirectory: URL) -> GitHubConnectionState {
        let gitRoot = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "rev-parse", "--show-toplevel"])
        guard gitRoot.exitCode == 0 else {
            return .disconnected
        }

        let remoteResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "remote", "get-url", "origin"])
        guard remoteResult.exitCode == 0, !remoteResult.standardOutput.isEmpty else {
            return .disconnected
        }

        let dirtyResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "status", "--porcelain"])
        let isDirty = !dirtyResult.standardOutput.isEmpty
        return .connected(remoteURL: remoteResult.standardOutput, isDirty: isDirty)
    }

    nonisolated private static func connectAndPush(baseDirectory: URL, remoteURL: String) -> LocalCommandResult {
        let repositoryExists = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "rev-parse", "--show-toplevel"])

        if repositoryExists.exitCode != 0 {
            let initResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "init"])
            guard initResult.exitCode == 0 else { return initResult }
        }

        let remoteExists = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "remote", "get-url", "origin"])
        let remoteResult: LocalCommandResult
        if remoteExists.exitCode == 0 {
            remoteResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "remote", "set-url", "origin", remoteURL])
        } else {
            remoteResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "remote", "add", "origin", remoteURL])
        }
        guard remoteResult.exitCode == 0 else { return remoteResult }

        let addResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "add", "-A"])
        guard addResult.exitCode == 0 else { return addResult }

        let statusResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "status", "--porcelain"])
        if !statusResult.standardOutput.isEmpty {
            let commitResult = LocalCommandRunner.run(
                "/usr/bin/env",
                arguments: ["git", "-C", baseDirectory.path, "commit", "-m", "Initial import from PapersApp"]
            )
            guard commitResult.exitCode == 0 else { return commitResult }
        }

        return LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "push", "-u", "origin", "HEAD"])
    }

    nonisolated private static func commitAndPush(baseDirectory: URL, message: String) -> LocalCommandResult {
        let addResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "add", "-A"])
        guard addResult.exitCode == 0 else { return addResult }

        let statusResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "status", "--porcelain"])
        if !statusResult.standardOutput.isEmpty {
            let commitResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "commit", "-m", message])
            guard commitResult.exitCode == 0 else { return commitResult }
        }

        return LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", baseDirectory.path, "push"])
    }
}

struct GitHubToolbarControls: View {
    let baseDirectory: URL

    @StateObject private var model = GitHubToolbarModel()

    var body: some View {
        HStack(spacing: 10) {
            if model.state.isConnected {
                Button {
                    Task {
                        await model.refresh(baseDirectory: baseDirectory)
                    }
                } label: {
                    Label("GitHub status", systemImage: model.state.statusIconName)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(model.state.statusColor)
                }
                .help(model.state.statusLabel)
                .accessibilityLabel(Text("GitHub status"))
                .buttonStyle(.plain)

                Button {
                    model.beginCommit()
                } label: {
                    if model.isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Commit and Push", systemImage: "arrow.up.circle")
                            .labelStyle(.iconOnly)
                    }
                }
                .help("Create a commit and push it to GitHub")
                .accessibilityLabel(Text("Commit and push"))
                .disabled(model.isWorking)
            } else {
                Button {
                    model.beginConnect()
                } label: {
                    Label("Connect GitHub", systemImage: "point.3.connected.trianglepath.dotted")
                        .labelStyle(.iconOnly)
                }
                .help("Connect this project to a GitHub repository")
                .accessibilityLabel(Text("Connect GitHub repository"))
                .disabled(model.isWorking)
            }
        }
        .task(id: baseDirectory.path) {
            await model.refresh(baseDirectory: baseDirectory)
        }
        .sheet(item: $model.connectDraft) { draft in
            GitHubConnectSheet(
                draft: draft,
                isWorking: model.isWorking,
                onCancel: {
                    model.connectDraft = nil
                },
                onSubmit: { remoteURL in
                    Task {
                        await model.connect(baseDirectory: baseDirectory, remoteURL: remoteURL)
                        await model.refresh(baseDirectory: baseDirectory)
                    }
                }
            )
        }
        .sheet(item: $model.commitDraft) { draft in
            GitCommitSheet(
                draft: draft,
                isWorking: model.isWorking,
                onCancel: {
                    model.commitDraft = nil
                },
                onSubmit: { message in
                    Task {
                        await model.commitAndPush(baseDirectory: baseDirectory, message: message)
                        await model.refresh(baseDirectory: baseDirectory)
                    }
                }
            )
        }
        .alert("GitHub", isPresented: Binding(
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

private struct GitHubConnectSheet: View {
    let draft: GitHubConnectDraft
    let isWorking: Bool
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var remoteURL: String

    init(
        draft: GitHubConnectDraft,
        isWorking: Bool,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.isWorking = isWorking
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _remoteURL = State(initialValue: draft.remoteURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect GitHub Repository")
                .font(.title3.weight(.semibold))

            Text("Enter the repository URL. PapersApp will initialize git if needed, add or update `origin`, then push the current project.")
                .foregroundStyle(.secondary)

            TextField("https://github.com/owner/repo.git", text: $remoteURL)
                .textFieldStyle(.roundedBorder)
                .disabled(isWorking)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .disabled(isWorking)

                Button("Complete") {
                    onSubmit(remoteURL)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isWorking || remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

private struct GitCommitSheet: View {
    let draft: GitCommitDraft
    let isWorking: Bool
    let onCancel: () -> Void
    let onSubmit: (String) -> Void

    @State private var message: String

    init(
        draft: GitCommitDraft,
        isWorking: Bool,
        onCancel: @escaping () -> Void,
        onSubmit: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.isWorking = isWorking
        self.onCancel = onCancel
        self.onSubmit = onSubmit
        _message = State(initialValue: draft.message)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Commit and Push")
                .font(.title3.weight(.semibold))

            Text("Enter a commit message. PapersApp will stage all changes, create a commit if needed, and push the current branch.")
                .foregroundStyle(.secondary)

            TextField("Update vocabulary workflow", text: $message)
                .textFieldStyle(.roundedBorder)
                .disabled(isWorking)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .disabled(isWorking)

                Button("Push") {
                    onSubmit(message)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isWorking || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
