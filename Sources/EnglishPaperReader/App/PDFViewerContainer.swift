import SwiftUI

struct PDFViewerContainer: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    let pdf: PDFRecord
    let fileURL: URL

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                PDFViewerRepresentable(
                    pdfID: pdf.id,
                    fileURL: fileURL,
                    appearances: workspace.appearances(forPDFID: pdf.id),
                    onHoverAppearance: { appearance, rect in
                        workspace.handleHover(appearance: appearance, rectInWindow: rect)
                    },
                    onHoverEnded: {
                        workspace.clearHover()
                    },
                    onTextSelection: { capture in
                        workspace.handleSelection(capture)
                    }
                )

                if let hover = workspace.hoverInfo {
                    HoverCardView(info: hover)
                        .frame(width: 280)
                        .position(hover.cardPosition(in: geometry.size))
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct HoverCardView: View {
    let info: HoverWordInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(info.word.surface)
                .font(.headline)
            if let reading = info.word.reading {
                Text(reading)
                    .foregroundStyle(.secondary)
            }
            if let pos = info.meaning?.pos {
                Text(pos)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            if let definition = info.meaning?.definition {
                Text(definition)
            }
            if let example = info.example, !example.en.isEmpty {
                Text(example.en)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Text(info.difficultyLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 10)
    }
}
