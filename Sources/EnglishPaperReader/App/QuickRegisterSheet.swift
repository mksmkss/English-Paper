import SwiftUI

struct QuickRegisterSheet: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @State private var reading = ""
    @State private var definition = ""
    @State private var pos = ""

    let selection: PDFSelectionCapture

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    card("Selection") {
                        Text(selection.surface)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .textSelection(.enabled)
                            .lineLimit(4)
                        if let snippet = selection.contextSnippet {
                            Text(snippet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }
                    }

                    card("Register") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pronunciation or kana")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Optional", text: $reading)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Meaning")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Required", text: $definition, axis: .vertical)
                                .lineLimit(3...6)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Part of speech")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Optional", text: $pos)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
            }
            .navigationTitle("Quick Register")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        workspace.cancelPendingSelection()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await workspace.registerPendingSelection(
                                reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
                                definition: definition,
                                pos: pos.isEmpty ? nil : pos
                            )
                        }
                    }
                    .disabled(definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 320)
    }

    @ViewBuilder
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
