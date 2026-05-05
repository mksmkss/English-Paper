import Foundation
import Testing
@testable import EnglishPaperReader

@MainActor
struct WorkspaceViewModelTests {
    @Test
    func selectingPDFSynchronizesSelectedDocumentAndOpenTabs() {
        let workspace = WorkspaceViewModel()
        let first = makePDF(id: "pdf-1", filename: "first.pdf")
        let second = makePDF(id: "pdf-2", filename: "second.pdf")

        workspace.pdfs = [first, second]
        workspace.selectPDF(first.id)
        workspace.selectPDF(second.id)
        workspace.selectPDF(first.id)

        #expect(workspace.selectedPDFID == first.id)
        #expect(workspace.selectedPDF?.id == first.id)
        #expect(workspace.openPDFIDs == [first.id, second.id])
    }

    @Test
    func closingSelectedTabFallsThroughToAdjacentOpenTab() {
        let workspace = WorkspaceViewModel()
        let first = makePDF(id: "pdf-1", filename: "first.pdf")
        let second = makePDF(id: "pdf-2", filename: "second.pdf")
        let third = makePDF(id: "pdf-3", filename: "third.pdf")

        workspace.pdfs = [first, second, third]
        workspace.openPDFIDs = [first.id, second.id, third.id]
        workspace.selectedPDFID = second.id

        workspace.closePDFTab(second.id)

        #expect(workspace.openPDFIDs == [first.id, third.id])
        #expect(workspace.selectedPDFID == third.id)
        #expect(workspace.selectedPDF?.id == third.id)
    }

    private func makePDF(id: String, filename: String) -> PDFRecord {
        PDFRecord(
            id: id,
            absolutePath: "/tmp/\(filename)",
            filename: filename,
            title: nil,
            folderID: nil,
            addedAt: DateFormatting.iso8601String()
        )
    }
}
