import AppKit
import Combine
import Foundation
import PDFKit
import SwiftUI

@MainActor
final class WorkspaceViewModel: ObservableObject {
    private(set) var appContext: AppContext?

    @Published var folders: [Folder] = []
    @Published var pdfs: [PDFRecord] = []
    @Published var words: [Word] = []

    @Published var selectedFolderID: String?
    @Published var selectedPDFID: String? {
        didSet {
            syncSelectedPDFState(from: oldValue)
        }
    }
    @Published var selectedWordID: String?
    @Published var openPDFIDs: [String] = []

    @Published var wordSort: WordSort = .difficultyDescending
    @Published var searchText = ""
    @Published var isWordPanelVisible = true
    @Published var startupMessage: String?

    @Published var hoverInfo: HoverWordInfo?
    @Published var pendingRegistration: PDFSelectionCapture?
    @Published var editingFolderDraft: FolderDraft?
    @Published var errorMessage: String?
    @Published var errorTitle = "Something went wrong"
    @Published var isShowingError = false

    private let maximumQuickRegistrationCharacters = 80
    private let maximumQuickRegistrationTokens = 6

    func configure(using appContext: AppContext) {
        guard self.appContext == nil else { return }
        self.appContext = appContext
        self.startupMessage = appContext.startupMessage
    }

    func loadInitialData() async {
        await reloadAll()
    }

    func reloadAll() async {
        guard let appContext else { return }
        do {
            folders = try appContext.folderRepository.fetchAll()
            pdfs = try appContext.pdfRepository.fetchAll()
            words = try appContext.wordRepository.fetchAll(sortedBy: wordSort)
            repairSelections()
        } catch {
            present(error)
        }
    }

    var selectedPDF: PDFRecord? {
        guard let selectedPDFID else { return nil }
        return pdfs.first { $0.id == selectedPDFID }
    }

    var selectedWord: Word? {
        words.first { $0.id == selectedWordID }
    }

    var filteredWords: [Word] {
        let base = words
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }

        let query = searchText.lowercased()
        return base.filter { word in
            word.surface.lowercased().contains(query) ||
            (word.reading?.lowercased().contains(query) ?? false) ||
            (primaryDefinition(for: word.id)?.lowercased().contains(query) ?? false)
        }
    }

    var windowTitle: String {
        if let pdf = selectedPDF {
            return pdf.filename
        }
        return "Library"
    }

    var hasSelectedPDF: Bool {
        selectedPDF != nil
    }

    var folderTree: [FolderNode] {
        FolderNode.makeTree(folders: folders, pdfs: pdfs)
    }

    func selectPDF(_ pdfID: String) {
        selectedPDFID = pdfID
    }

    func closePDFTab(_ pdfID: String) {
        guard let closingIndex = openPDFIDs.firstIndex(of: pdfID) else { return }
        openPDFIDs.remove(at: closingIndex)

        if selectedPDFID == pdfID {
            if openPDFIDs.indices.contains(closingIndex) {
                selectedPDFID = openPDFIDs[closingIndex]
            } else {
                selectedPDFID = openPDFIDs.last
            }
        }
    }

    func selectWord(_ wordID: String?) {
        selectedWordID = wordID
    }

    func toggleWordPanel() {
        isWordPanelVisible.toggle()
    }

    func updateWordSort(_ sort: WordSort) async {
        wordSort = sort
        await reloadWords()
    }

    func reloadWords() async {
        guard let appContext else { return }
        do {
            words = try appContext.wordRepository.fetchAll(sortedBy: wordSort)
        } catch {
            present(error)
        }
    }

    func requestAddFolder(parentID: String?) {
        editingFolderDraft = FolderDraft(id: UUID().uuidString.lowercased(), name: "", parentID: parentID, mode: .create)
    }

    func requestRenameFolder(_ folder: Folder) {
        editingFolderDraft = FolderDraft(id: folder.id, name: folder.name, parentID: folder.parentID, mode: .rename)
    }

    func saveFolderDraft(_ draft: FolderDraft) async {
        guard let appContext else { return }
        do {
            switch draft.mode {
            case .create:
                let folder = Folder(
                    id: draft.id,
                    name: draft.name,
                    parentID: draft.parentID,
                    createdAt: DateFormatting.iso8601String()
                )
                try appContext.folderRepository.insert(folder)
            case .rename:
                let folder = Folder(
                    id: draft.id,
                    name: draft.name,
                    parentID: draft.parentID,
                    createdAt: folders.first(where: { $0.id == draft.id })?.createdAt ?? DateFormatting.iso8601String()
                )
                try appContext.folderRepository.update(folder)
            }

            editingFolderDraft = nil
            await reloadAll()
        } catch {
            present(error)
        }
    }

    func deleteFolder(_ folderID: String) async {
        guard let appContext else { return }
        do {
            try appContext.folderRepository.delete(id: folderID)
            await reloadAll()
        } catch {
            present(error)
        }
    }

    func promptAddPDF(to folderID: String?) async {
        do {
            guard let url = try AppOpenPanel.choosePDF() else { return }
            guard let appContext else { return }
            _ = try appContext.pdfRepository.register(fileURL: url, folderID: folderID)
            await reloadAll()
            if let inserted = try appContext.pdfRepository.fetchAll().first(where: { $0.absolutePath == url.path }) {
                selectPDF(inserted.id)
            }
        } catch {
            present(error)
        }
    }

    func promptRelinkPDF(_ pdf: PDFRecord) async {
        do {
            guard let url = try AppOpenPanel.choosePDF() else { return }
            guard let appContext else { return }
            try appContext.pdfRepository.relink(id: pdf.id, to: url)
            await reloadAll()
            selectPDF(pdf.id)
        } catch {
            present(error)
        }
    }

    func movePDF(_ pdfID: String, to folderID: String?) async {
        guard let appContext, var pdf = pdfs.first(where: { $0.id == pdfID }) else { return }
        do {
            pdf.folderID = folderID
            try appContext.pdfRepository.update(pdf)
            await reloadAll()
        } catch {
            present(error)
        }
    }

    func handleHover(appearance: Appearance, rectInWindow: CGRect) {
        guard let appContext else { return }
        do {
            let resolvedWord: Word?
            if let cachedWord = words.first(where: { $0.id == appearance.wordID }) {
                resolvedWord = cachedWord
            } else {
                resolvedWord = try appContext.wordRepository.fetch(id: appearance.wordID)
            }
            guard let word = resolvedWord else {
                hoverInfo = nil
                return
            }

            let meanings = try appContext.meaningRepository.fetchAll(wordID: word.id)
            let preferredMeaning = appearance.meaningID.flatMap { meaningID in
                meanings.first(where: { $0.id == meaningID })
            } ?? meanings.sorted(by: { $0.sortOrder < $1.sortOrder }).first
            let example = try preferredMeaning.flatMap { try appContext.exampleRepository.fetchAll(meaningID: $0.id).first }

            hoverInfo = HoverWordInfo(
                surface: word.surface,
                word: word,
                meaning: preferredMeaning,
                example: example,
                rectInWindow: rectInWindow
            )
        } catch {
            hoverInfo = nil
            present(error)
        }
    }

    func clearHover() {
        hoverInfo = nil
    }

    func handleSelection(_ selection: PDFSelectionCapture) {
        let normalizedSurface = selection.surface.normalizedWordSurface
        guard !normalizedSurface.isEmpty else { return }

        guard normalizedSurface.isReasonableQuickRegistrationSelection(
            maxCharacters: maximumQuickRegistrationCharacters,
            maxTokens: maximumQuickRegistrationTokens
        ) else {
            presentMessage("Selection is too long. Zoom in and select one word or a short phrase.")
            return
        }

        guard selection.lineCount <= 1 else {
            presentMessage("Selection is too long. Zoom in and select one word or a short phrase.")
            return
        }

        pendingRegistration = PDFSelectionCapture(
            pdfID: selection.pdfID,
            surface: normalizedSurface,
            page: selection.page,
            boundingBox: selection.boundingBox,
            contextSnippet: selection.contextSnippet?.normalizedSnippet,
            lineCount: selection.lineCount
        )
    }

    func registerPendingSelection(reading: String, definition: String, pos: String?) async {
        guard let appContext, let selection = pendingRegistration else { return }
        do {
            let word = try appContext.wordRepository.upsert(surface: selection.surface, reading: reading)
            let existingMeanings = try appContext.meaningRepository.fetchAll(wordID: word.id)
            let normalizedPOS = pos?.nilIfBlank
            let meaning = existingMeanings.first {
                $0.definition == definition && $0.pos == normalizedPOS
            } ?? {
                let sortOrder = (existingMeanings.map(\.sortOrder).max() ?? -1) + 1
                return Meaning(
                    id: UUID().uuidString.lowercased(),
                    wordID: word.id,
                    pos: normalizedPOS,
                    definition: definition,
                    note: nil,
                    sortOrder: sortOrder
                )
            }()

            if !existingMeanings.contains(where: { $0.id == meaning.id }) {
                try appContext.meaningRepository.insert(meaning)
            }

            let appearance = Appearance(
                id: UUID().uuidString.lowercased(),
                wordID: word.id,
                meaningID: meaning.id,
                pdfID: selection.pdfID,
                page: selection.page,
                bboxX: selection.boundingBox.origin.x,
                bboxY: selection.boundingBox.origin.y,
                bboxWidth: selection.boundingBox.width,
                bboxHeight: selection.boundingBox.height,
                contextSnippet: selection.contextSnippet,
                addedAt: DateFormatting.iso8601String()
            )
            try appContext.appearanceRepository.insertAndRefreshCount(appearance, wordRepository: appContext.wordRepository)

            pendingRegistration = nil
            await reloadAll()
            selectedWordID = word.id
        } catch {
            present(error)
        }
    }

    func cancelPendingSelection() {
        pendingRegistration = nil
    }

    func deleteWord(_ wordID: String) async {
        guard let appContext else { return }
        do {
            try appContext.wordRepository.delete(id: wordID)
            await reloadAll()
        } catch {
            present(error)
        }
    }

    func saveWord(_ word: Word) async {
        guard let appContext else { return }
        do {
            try appContext.wordRepository.update(word)
            await reloadWords()
        } catch {
            present(error)
        }
    }

    func saveMeaning(_ meaning: Meaning) async {
        guard let appContext else { return }
        do {
            if try appContext.meaningRepository.fetch(id: meaning.id) == nil {
                try appContext.meaningRepository.insert(meaning)
            } else {
                try appContext.meaningRepository.update(meaning)
            }
            await reloadWords()
        } catch {
            present(error)
        }
    }

    func deleteMeaning(_ meaningID: String, wordID: String) async {
        guard let appContext else { return }
        do {
            try appContext.meaningRepository.delete(id: meaningID)
            try appContext.wordRepository.refreshTotalCount(wordID: wordID)
            await reloadAll()
        } catch {
            present(error)
        }
    }

    func saveExample(_ example: Example) async {
        guard let appContext else { return }
        do {
            if try appContext.exampleRepository.fetch(id: example.id) == nil {
                try appContext.exampleRepository.insert(example)
            } else {
                try appContext.exampleRepository.update(example)
            }
            objectWillChange.send()
        } catch {
            present(error)
        }
    }

    func deleteExample(_ exampleID: String) async {
        guard let appContext else { return }
        do {
            try appContext.exampleRepository.delete(id: exampleID)
            objectWillChange.send()
        } catch {
            present(error)
        }
    }

    func appearances(for wordID: String) -> [Appearance] {
        guard let appContext else { return [] }
        return (try? appContext.appearanceRepository.fetchAll(wordID: wordID)) ?? []
    }

    func primaryDefinition(for wordID: String) -> String? {
        meanings(for: wordID)
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .first?
            .definition
    }

    func appearances(forPDFID pdfID: String) -> [Appearance] {
        guard let appContext else { return [] }
        return (try? appContext.appearanceRepository.fetchAll(pdfID: pdfID)) ?? []
    }

    func meanings(for wordID: String) -> [Meaning] {
        guard let appContext else { return [] }
        return (try? appContext.meaningRepository.fetchAll(wordID: wordID)) ?? []
    }

    func examples(for meaningID: String) -> [Example] {
        guard let appContext else { return [] }
        return (try? appContext.exampleRepository.fetchAll(meaningID: meaningID)) ?? []
    }

    func jumpToAppearance(_ appearance: Appearance) {
        selectPDF(appearance.pdfID)
        NotificationCenter.default.post(name: .jumpToAppearance, object: appearance)
    }

    func zoomInPDF() {
        guard let pdfID = selectedPDF?.id else { return }
        NotificationCenter.default.post(name: .zoomInPDF, object: pdfID)
    }

    func zoomOutPDF() {
        guard let pdfID = selectedPDF?.id else { return }
        NotificationCenter.default.post(name: .zoomOutPDF, object: pdfID)
    }

    func fitPDFToWindow() {
        guard let pdfID = selectedPDF?.id else { return }
        NotificationCenter.default.post(name: .fitPDFToWindow, object: pdfID)
    }

    func clearError() {
        errorTitle = "Something went wrong"
        errorMessage = nil
        isShowingError = false
    }

    private func present(_ error: Error) {
        errorTitle = "Unable to complete action"
        errorMessage = error.localizedDescription
        isShowingError = true
    }

    private func presentMessage(_ message: String) {
        errorTitle = "Check your selection"
        errorMessage = message
        isShowingError = true
    }

    private func repairSelections() {
        openPDFIDs.removeAll { openID in
            !pdfs.contains(where: { $0.id == openID })
        }

        if let selectedPDFID, !pdfs.contains(where: { $0.id == selectedPDFID }) {
            self.selectedPDFID = nil
        }

        if selectedPDFID == nil, let firstOpenPDFID = openPDFIDs.last ?? pdfs.first?.id {
            selectedPDFID = firstOpenPDFID
        }
        if let selectedWordID, !words.contains(where: { $0.id == selectedWordID }) {
            self.selectedWordID = nil
        }
    }

    private func syncSelectedPDFState(from oldValue: String?) {
        guard selectedPDFID != oldValue else { return }
        guard let selectedPDFID else { return }
        guard pdfs.contains(where: { $0.id == selectedPDFID }) else { return }

        if !openPDFIDs.contains(selectedPDFID) {
            openPDFIDs.append(selectedPDFID)
        }
    }
}

struct FolderDraft: Identifiable {
    enum Mode {
        case create
        case rename
    }

    let id: String
    var name: String
    var parentID: String?
    let mode: Mode
}

struct FolderNode: Identifiable {
    let id: String
    let folder: Folder?
    let pdfs: [PDFRecord]
    let children: [FolderNode]

    static func makeTree(folders: [Folder], pdfs: [PDFRecord]) -> [FolderNode] {
        func build(parentID: String?) -> [FolderNode] {
            folders
                .filter { $0.parentID == parentID }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { folder in
                    FolderNode(
                        id: folder.id,
                        folder: folder,
                        pdfs: pdfs.filter { $0.folderID == folder.id }.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending },
                        children: build(parentID: folder.id)
                    )
                }
        }

        let uncategorized = FolderNode(
            id: "uncategorized",
            folder: nil,
            pdfs: pdfs.filter { $0.folderID == nil }.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending },
            children: []
        )

        return build(parentID: nil) + [uncategorized]
    }
}

struct HoverWordInfo: Identifiable {
    let id = UUID()
    let surface: String
    let word: Word
    let meaning: Meaning?
    let example: Example?
    let rectInWindow: CGRect

    var difficultyLabel: String {
        switch word.totalCount {
        case 0...1:
            return "☆☆☆ 初見"
        case 2...3:
            return "★☆☆ やや苦手"
        default:
            return "★★★ 苦手！"
        }
    }

    func cardPosition(in size: CGSize) -> CGPoint {
        let cardWidth: CGFloat = 280
        let cardHeight: CGFloat = 170
        let padding: CGFloat = 18

        let desiredX = rectInWindow.midX + (cardWidth / 2) + 16
        let desiredY = rectInWindow.minY - (cardHeight / 2) - 12

        return CGPoint(
            x: min(max(desiredX, padding + cardWidth / 2), size.width - padding - cardWidth / 2),
            y: min(max(desiredY, padding + cardHeight / 2), size.height - padding - cardHeight / 2)
        )
    }
}

struct PDFSelectionCapture: Identifiable {
    let id = UUID()
    let pdfID: String
    let surface: String
    let page: Int
    let boundingBox: CGRect
    let contextSnippet: String?
    let lineCount: Int
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }

    var normalizedWordSurface: String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSnippet: String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isReasonableQuickRegistrationSelection(maxCharacters: Int, maxTokens: Int) -> Bool {
        if count > maxCharacters {
            return false
        }

        return split(whereSeparator: \.isWhitespace).count <= maxTokens
    }
}

extension Notification.Name {
    static let jumpToAppearance = Notification.Name("jumpToAppearance")
    static let zoomInPDF = Notification.Name("zoomInPDF")
    static let zoomOutPDF = Notification.Name("zoomOutPDF")
    static let fitPDFToWindow = Notification.Name("fitPDFToWindow")
    static let requestAddPDFCommand = Notification.Name("requestAddPDFCommand")
    static let requestNewFolderCommand = Notification.Name("requestNewFolderCommand")
    static let toggleWordPanelCommand = Notification.Name("toggleWordPanelCommand")
    static let zoomInPDFCommand = Notification.Name("zoomInPDFCommand")
    static let zoomOutPDFCommand = Notification.Name("zoomOutPDFCommand")
    static let fitPDFToWindowCommand = Notification.Name("fitPDFToWindowCommand")
}
