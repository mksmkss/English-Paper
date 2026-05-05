import Foundation
import SQLite3
import Testing
@testable import EnglishPaperReader

struct RepositoryTests {
    @Test
    func wordSurfaceLookupIsCaseInsensitiveAndCountsRefresh() throws {
        let root = try temporaryDirectory()
        let paths = try AppPaths(baseDirectory: root)
        _ = try DatabaseBootstrapper(paths: paths).prepareDatabase()

        let database = try SQLiteDatabase(path: paths.databaseURL.path)
        let wordRepository = WordRepository(database: database)
        let meaningRepository = MeaningRepository(database: database)
        let pdfRepository = PDFRepository(database: database)
        let appearanceRepository = AppearanceRepository(database: database)

        let pdf = PDFRecord(
            id: "abc123456789def0",
            absolutePath: nil,
            filename: "paper.pdf",
            title: nil,
            folderID: nil,
            addedAt: DateFormatting.iso8601String()
        )
        try pdfRepository.insert(pdf)

        let word = try wordRepository.upsert(surface: "Mitochondria", reading: "ミトコンドリア")
        let fetched = try wordRepository.fetchBySurface("mitochondria")
        #expect(fetched?.id == word.id)

        let meaning = Meaning(
            id: UUID().uuidString.lowercased(),
            wordID: word.id,
            pos: "noun",
            definition: "The organelles that generate ATP.",
            note: nil,
            sortOrder: 0
        )
        try meaningRepository.insert(meaning)

        let appearance = Appearance(
            id: UUID().uuidString.lowercased(),
            wordID: word.id,
            meaningID: meaning.id,
            pdfID: pdf.id,
            page: 0,
            bboxX: 10,
            bboxY: 10,
            bboxWidth: 50,
            bboxHeight: 12,
            contextSnippet: "The mitochondria is the powerhouse of the cell.",
            addedAt: DateFormatting.iso8601String()
        )
        try appearanceRepository.insertAndRefreshCount(appearance, wordRepository: wordRepository)

        let updatedWord = try wordRepository.fetch(id: word.id)
        #expect(updatedWord?.totalCount == 1)
    }

    @Test
    func missingPDFPathsAreClearedDuringScan() throws {
        let root = try temporaryDirectory()
        let paths = try AppPaths(baseDirectory: root)
        _ = try DatabaseBootstrapper(paths: paths).prepareDatabase()

        let database = try SQLiteDatabase(path: paths.databaseURL.path)
        let pdfRepository = PDFRepository(database: database)

        let missingPath = root.appendingPathComponent("missing.pdf").path
        try pdfRepository.insert(
            PDFRecord(
                id: "missing-pdf-0001",
                absolutePath: missingPath,
                filename: "missing.pdf",
                title: nil,
                folderID: nil,
                addedAt: DateFormatting.iso8601String()
            )
        )

        try pdfRepository.markMissingFiles()
        let record = try pdfRepository.fetch(id: "missing-pdf-0001")
        #expect(record?.absolutePath == nil)
    }
}
