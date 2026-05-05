import SwiftUI

struct PDFWorkspaceView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 0) {
            PDFTabBar()
            Divider()
            Group {
                if let pdf = workspace.selectedPDF, let path = pdf.absolutePath {
                    PDFViewerContainer(pdf: pdf, fileURL: URL(fileURLWithPath: path))
                } else if let pdf = workspace.selectedPDF, pdf.isMissing {
                    MissingPDFView(pdf: pdf)
                } else {
                    EmptyPDFStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct EmptyPDFStateView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Open a PDF")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Choose a paper from the sidebar or add a new PDF.")
                .foregroundStyle(.secondary)
            Button {
                Task {
                    await workspace.promptAddPDF(to: workspace.selectedFolderID)
                }
            } label: {
                Label("Add PDF", systemImage: "plus.rectangle.on.folder")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct PDFTabBar: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(workspace.openPDFIDs, id: \.self) { pdfID in
                    if let pdf = workspace.pdfs.first(where: { $0.id == pdfID }) {
                        HStack(spacing: 6) {
                            Button {
                                workspace.selectPDF(pdfID)
                            } label: {
                                Text(pdf.filename)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())

                            Button {
                                workspace.closePDFTab(pdfID)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(minWidth: 180, maxWidth: 280, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(workspace.currentPDFTabID == pdfID ? Color.accentColor.opacity(0.18) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            workspace.selectPDF(pdfID)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct MissingPDFView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let pdf: PDFRecord

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text("File Not Found")
                .font(.title2)
                .fontWeight(.semibold)
            Text(pdf.filename)
                .foregroundStyle(.secondary)
            Button("Relink PDF") {
                Task {
                    await workspace.promptRelinkPDF(pdf)
                }
            }
        }
    }
}
