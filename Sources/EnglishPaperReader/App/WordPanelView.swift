import SwiftUI

struct WordPanelView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Words")
                    .font(.headline)
                Spacer()
                Picker("Sort", selection: Binding(
                    get: { workspace.wordSort },
                    set: { newValue in
                        Task {
                            await workspace.updateWordSort(newValue)
                        }
                    }
                )) {
                    Text("Difficulty").tag(WordSort.difficultyDescending)
                    Text("Added").tag(WordSort.addedAtDescending)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            TextField("Search words or definitions", text: $workspace.searchText)
                .textFieldStyle(.roundedBorder)
                .help("Search registered words, pronunciations, or definitions")
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            List(selection: $workspace.selectedWordID) {
                ForEach(workspace.filteredWords, id: \.id) { word in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.surface)
                                .lineLimit(2)
                            if let definition = workspace.primaryDefinition(for: word.id), !definition.isEmpty {
                                Text(definition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("\(word.totalCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workspace.selectWord(word.id)
                    }
                }
            }
        }
        .background(.background)
    }
}
