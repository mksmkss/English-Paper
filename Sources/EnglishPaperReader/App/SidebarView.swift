import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Task {
                        await workspace.promptAddPDF(to: workspace.selectedFolderID)
                    }
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .help("Import a PDF into the current library or selected folder")
                .accessibilityLabel(Text("Add PDF"))

                Button {
                    workspace.requestAddFolder(parentID: nil)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.bordered)
                .help("Create a folder to organize PDFs")
                .accessibilityLabel(Text("New Folder"))
            }
            .frame(maxWidth: .infinity)
            .padding(12)

            List(selection: $workspace.selectedPDFID) {
                if let message = workspace.startupMessage {
                    Section("Startup") {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Library") {
                    ForEach(workspace.folderTree) { node in
                        FolderTreeRow(node: node)
                    }
                }
            }
        }
        .navigationTitle("Explorer")
    }
}

private struct FolderTreeRow: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let node: FolderNode

    var body: some View {
        if let folder = node.folder {
            DisclosureGroup(folder.name) {
                ForEach(node.children) { child in
                    FolderTreeRow(node: child)
                }
                ForEach(node.pdfs, id: \.id) { pdf in
                    PDFSidebarRow(pdf: pdf)
                }
            }
            .contextMenu {
                Button("Add Subfolder") {
                    workspace.requestAddFolder(parentID: folder.id)
                }
                Button("Rename") {
                    workspace.requestRenameFolder(folder)
                }
                Button("Add PDF") {
                    Task {
                        await workspace.promptAddPDF(to: folder.id)
                    }
                }
                Divider()
                Button("Delete Folder", role: .destructive) {
                    Task {
                        await workspace.deleteFolder(folder.id)
                    }
                }
            }
            .onTapGesture {
                workspace.selectedFolderID = folder.id
            }
        } else {
            DisclosureGroup("Uncategorized") {
                ForEach(node.pdfs, id: \.id) { pdf in
                    PDFSidebarRow(pdf: pdf)
                }
            }
        }
    }
}

private struct PDFSidebarRow: View {
    let pdf: PDFRecord

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
            Text(pdf.filename)
                .lineLimit(1)
            Spacer(minLength: 8)
            if pdf.isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .tag(pdf.id)
        .contextMenu {
            PDFSidebarContextMenu(pdf: pdf)
        }
    }
}

private struct PDFSidebarContextMenu: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let pdf: PDFRecord

    var body: some View {
        Group {
            if pdf.isMissing {
                Button("Relink File") {
                    Task {
                        await workspace.promptRelinkPDF(pdf)
                    }
                }
            }
            Button("Move To Uncategorized") {
                Task {
                    await workspace.movePDF(pdf.id, to: nil)
                }
            }
        }
    }
}
