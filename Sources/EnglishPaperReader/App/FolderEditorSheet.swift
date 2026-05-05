import SwiftUI

struct FolderEditorSheet: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @State private var draft: FolderDraft

    init(draft: FolderDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Folder name", text: $draft.name)
            }
            .navigationTitle(draft.mode == .create ? "New Folder" : "Rename Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        workspace.editingFolderDraft = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await workspace.saveFolderDraft(draft)
                        }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 140)
    }
}
