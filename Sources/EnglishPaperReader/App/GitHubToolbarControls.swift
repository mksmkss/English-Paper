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
            return "Connect vocabulary data sync to GitHub"
        case .connected(_, let isDirty):
            return isDirty ? "Vocabulary data changed and is ready to sync" : "Vocabulary data sync is up to date"
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

    func refresh(paths: AppPaths) async {
        let result = await Task.detached(priority: .utility) {
            GitHubToolbarModel.resolveGitHubState(paths: paths)
        }.value
        state = result
    }

    func beginConnect() {
        connectDraft = GitHubConnectDraft(remoteURL: state.remoteURL ?? "")
    }

    func beginCommit() {
        commitDraft = GitCommitDraft(message: "")
    }

    func connect(paths: AppPaths, remoteURL: String) async {
        let sanitizedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedURL.isEmpty else {
            alertMessage = "Enter a GitHub repository URL for vocabulary sync."
            return
        }

        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let result = await Task.detached(priority: .userInitiated) {
            GitHubToolbarModel.connectAndPush(paths: paths, remoteURL: sanitizedURL)
        }.value

        connectDraft = nil
        await handle(result: result, successMessage: "GitHub vocabulary sync connected.", paths: paths)
    }

    func commitAndPush(paths: AppPaths, message: String) async {
        let sanitizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedMessage.isEmpty else {
            alertMessage = "Enter a commit message."
            return
        }

        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let result = await Task.detached(priority: .userInitiated) {
            GitHubToolbarModel.commitAndPush(paths: paths, message: sanitizedMessage)
        }.value

        commitDraft = nil
        await handle(result: result, successMessage: "Vocabulary data pushed successfully.", paths: paths)
    }

    private func handle(result: LocalCommandResult, successMessage: String, paths: AppPaths) async {
        if result.exitCode == 0 {
            let output = [result.standardOutput, result.standardError]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            alertMessage = output.isEmpty ? successMessage : output
            await refresh(paths: paths)
        } else {
            let output = [result.standardError, result.standardOutput]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            alertMessage = output.isEmpty ? "GitHub action failed." : output
        }
    }

    nonisolated private static func resolveGitHubState(paths: AppPaths) -> GitHubConnectionState {
        let gitRoot = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "rev-parse", "--show-toplevel"])
        guard gitRoot.exitCode == 0 else {
            return .disconnected
        }

        let remoteResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "remote", "get-url", "origin"])
        guard remoteResult.exitCode == 0, !remoteResult.standardOutput.isEmpty else {
            return .disconnected
        }

        let dirtyResult = LocalCommandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", paths.syncDirectory.path, "status", "--porcelain", "--", "backup.sql"]
        )
        let isDirty = !dirtyResult.standardOutput.isEmpty
        return .connected(remoteURL: remoteResult.standardOutput, isDirty: isDirty)
    }

    nonisolated private static func connectAndPush(paths: AppPaths, remoteURL: String) -> LocalCommandResult {
        let backupResult = DatabaseBackupExporter(paths: paths).exportResult()
        guard backupResult.exitCode == 0 else { return backupResult }

        let repositoryExists = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "rev-parse", "--show-toplevel"])

        if repositoryExists.exitCode != 0 {
            let initResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "init"])
            guard initResult.exitCode == 0 else { return initResult }
        }

        let remoteExists = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "remote", "get-url", "origin"])
        let remoteResult: LocalCommandResult
        if remoteExists.exitCode == 0 {
            remoteResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "remote", "set-url", "origin", remoteURL])
        } else {
            remoteResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "remote", "add", "origin", remoteURL])
        }
        guard remoteResult.exitCode == 0 else { return remoteResult }

        let addResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "add", "--", "backup.sql"])
        guard addResult.exitCode == 0 else { return addResult }

        let statusResult = LocalCommandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", paths.syncDirectory.path, "status", "--porcelain", "--", "backup.sql"]
        )
        if !statusResult.standardOutput.isEmpty {
            let commitResult = LocalCommandRunner.run(
                "/usr/bin/env",
                arguments: ["git", "-C", paths.syncDirectory.path, "commit", "-m", "Initial vocabulary backup from PapersApp"]
            )
            guard commitResult.exitCode == 0 else { return commitResult }
        }

        return LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "push", "-u", "origin", "HEAD"])
    }

    nonisolated private static func commitAndPush(paths: AppPaths, message: String) -> LocalCommandResult {
        let backupResult = DatabaseBackupExporter(paths: paths).exportResult()
        guard backupResult.exitCode == 0 else { return backupResult }

        let addResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "add", "--", "backup.sql"])
        guard addResult.exitCode == 0 else { return addResult }

        let statusResult = LocalCommandRunner.run(
            "/usr/bin/env",
            arguments: ["git", "-C", paths.syncDirectory.path, "status", "--porcelain", "--", "backup.sql"]
        )
        if !statusResult.standardOutput.isEmpty {
            let commitResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "commit", "-m", message])
            guard commitResult.exitCode == 0 else { return commitResult }
        }

        return LocalCommandRunner.run("/usr/bin/env", arguments: ["git", "-C", paths.syncDirectory.path, "push"])
    }
}

struct GitHubToolbarControls: View {
    let paths: AppPaths

    @StateObject private var model = GitHubToolbarModel()

    var body: some View {
        HStack(spacing: 10) {
            if model.state.isConnected {
                Button {
                    Task {
                        await model.refresh(paths: paths)
                    }
                } label: {
                    Label("Data sync status", systemImage: model.state.statusIconName)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(model.state.statusColor)
                }
                .help(model.state.statusLabel)
                .accessibilityLabel(Text("Data sync status"))
                .buttonStyle(.plain)

                Button {
                    model.beginCommit()
                } label: {
                    if model.isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Sync Data", systemImage: "arrow.up.circle")
                            .labelStyle(.iconOnly)
                    }
                }
                .help("Commit the latest vocabulary backup and push it to GitHub")
                .accessibilityLabel(Text("Sync vocabulary data"))
                .disabled(model.isWorking)
            } else {
                Button {
                    model.beginConnect()
                } label: {
                    Label("Connect Data Sync", systemImage: "point.3.connected.trianglepath.dotted")
                        .labelStyle(.iconOnly)
                }
                .help("Connect vocabulary data sync to a GitHub repository")
                .accessibilityLabel(Text("Connect GitHub data sync"))
                .disabled(model.isWorking)
            }
        }
        .task(id: paths.syncDirectory.path) {
            await model.refresh(paths: paths)
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
                        await model.connect(paths: paths, remoteURL: remoteURL)
                        await model.refresh(paths: paths)
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
                        await model.commitAndPush(paths: paths, message: message)
                        await model.refresh(paths: paths)
                    }
                }
            )
        }
        .alert("Vocabulary Sync", isPresented: Binding(
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
            Text("Connect GitHub Data Sync")
                .font(.title3.weight(.semibold))

            Text("Enter a GitHub repository URL for your vocabulary data. PapersApp only syncs `backup.sql` from Application Support. PDF files stay on this Mac, so another Mac may ask you to relink missing PDFs.")
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
            Text("Sync Vocabulary Data")
                .font(.title3.weight(.semibold))

            Text("Enter a commit message. PapersApp refreshes `backup.sql`, stages only that file, creates a commit if needed, and pushes your vocabulary data to GitHub.")
                .foregroundStyle(.secondary)

            TextField("Update saved vocabulary", text: $message)
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
