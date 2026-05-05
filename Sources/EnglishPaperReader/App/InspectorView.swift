import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        Group {
            if let word = workspace.selectedWord {
                WordInspector(word: word)
            } else {
                ContentUnavailableView(
                    "Select a Word",
                    systemImage: "character.book.closed",
                    description: Text("Choose a word from the bottom panel or register one from the PDF.")
                )
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    workspace.toggleWordPanel()
                } label: {
                    Label("Toggle Word Panel", systemImage: "rectangle.bottomthird.inset.filled")
                }
                .help("Show or hide the word list")
            }
        }
    }
}

private struct WordInspector: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let word: Word
    @State private var editableWord: Word
    @State private var isShowingDeleteConfirmation = false

    init(word: Word) {
        self.word = word
        _editableWord = State(initialValue: word)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Word")
                        .font(.headline)
                    TextField("Surface", text: $editableWord.surface)
                    TextField("Pronunciation or kana", text: Binding(
                        get: { editableWord.reading ?? "" },
                        set: { editableWord.reading = $0.isEmpty ? nil : $0 }
                    ))
                    HStack {
                        Text("Appearances: \(editableWord.totalCount)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Save") {
                            Task {
                                await workspace.saveWord(editableWord)
                            }
                        }
                        Button("Delete", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }

                MeaningListSection(wordID: editableWord.id)
                AppearanceListSection(wordID: editableWord.id)
            }
            .padding(16)
        }
        .onChange(of: word.id) { _, _ in
            editableWord = word
        }
        .confirmationDialog(
            "Delete this word and all related meanings, examples, and appearances?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Word", role: .destructive) {
                Task {
                    await workspace.deleteWord(editableWord.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct MeaningListSection: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let wordID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meanings")
                    .font(.headline)
                Spacer()
                Button("Add Meaning") {
                    let nextOrder = (workspace.meanings(for: wordID).map(\.sortOrder).max() ?? -1) + 1
                    Task {
                        await workspace.saveMeaning(
                            Meaning(
                                id: UUID().uuidString.lowercased(),
                                wordID: wordID,
                                pos: nil,
                                definition: "New meaning",
                                note: nil,
                                sortOrder: nextOrder
                            )
                        )
                    }
                }
            }

            ForEach(workspace.meanings(for: wordID), id: \.id) { meaning in
                MeaningEditorCard(meaning: meaning)
            }
        }
    }
}

private struct MeaningEditorCard: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @State private var draft: Meaning

    init(meaning: Meaning) {
        _draft = State(initialValue: meaning)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Part of speech", text: Binding(
                get: { draft.pos ?? "" },
                set: { draft.pos = $0.isEmpty ? nil : $0 }
            ))
            TextField("Definition", text: $draft.definition, axis: .vertical)
            TextField("Note", text: Binding(
                get: { draft.note ?? "" },
                set: { draft.note = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)

            HStack {
                Button("Save") {
                    Task {
                        await workspace.saveMeaning(draft)
                    }
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await workspace.deleteMeaning(draft.id, wordID: draft.wordID)
                    }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Examples")
                    .font(.subheadline)
                    .fontWeight(.medium)
                ForEach(workspace.examples(for: draft.id), id: \.id) { example in
                    ExampleEditorRow(example: example)
                }
                Button("Add Example") {
                    Task {
                        await workspace.saveExample(
                            Example(
                                id: UUID().uuidString.lowercased(),
                                meaningID: draft.id,
                                en: "",
                                ja: nil,
                                sourcePDFID: nil,
                                sortOrder: workspace.examples(for: draft.id).count
                            )
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ExampleEditorRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @State private var draft: Example

    init(example: Example) {
        _draft = State(initialValue: example)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("English example", text: $draft.en, axis: .vertical)
            TextField("Japanese translation", text: Binding(
                get: { draft.ja ?? "" },
                set: { draft.ja = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            HStack {
                Button("Save") {
                    Task {
                        await workspace.saveExample(draft)
                    }
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await workspace.deleteExample(draft.id)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct AppearanceListSection: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let wordID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearances")
                .font(.headline)
            ForEach(workspace.appearances(for: wordID), id: \.id) { appearance in
                Button {
                    workspace.jumpToAppearance(appearance)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page \(appearance.page + 1)")
                            .fontWeight(.medium)
                        if let snippet = appearance.contextSnippet {
                            Text(snippet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
