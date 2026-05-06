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

    @Test
    func backupSQLRestoresFoldersWordsAndAppearances() throws {
        let root = try temporaryDirectory()
        let paths = try AppPaths(baseDirectory: root)
        _ = try DatabaseBootstrapper(paths: paths).prepareDatabase()

        var database = try SQLiteDatabase(path: paths.databaseURL.path)
        var folderRepository = FolderRepository(database: database)
        var pdfRepository = PDFRepository(database: database)
        var wordRepository = WordRepository(database: database)
        var meaningRepository = MeaningRepository(database: database)
        var exampleRepository = ExampleRepository(database: database)
        var appearanceRepository = AppearanceRepository(database: database)

        let rootFolder = Folder(
            id: "folder-root",
            name: "Research",
            parentID: nil,
            createdAt: DateFormatting.iso8601String()
        )
        let childFolder = Folder(
            id: "folder-child",
            name: "Vision",
            parentID: rootFolder.id,
            createdAt: DateFormatting.iso8601String()
        )
        try folderRepository.insert(rootFolder)
        try folderRepository.insert(childFolder)

        let pdf = PDFRecord(
            id: "pdf-restore-0001",
            absolutePath: nil,
            filename: "clip.pdf",
            title: "CLIP",
            folderID: childFolder.id,
            addedAt: DateFormatting.iso8601String()
        )
        try pdfRepository.insert(pdf)

        let word = try wordRepository.upsert(surface: "instance", reading: "インスタンス")
        let meaning = Meaning(
            id: "meaning-restore-0001",
            wordID: word.id,
            pos: "noun",
            definition: "An example or case.",
            note: "Restored from backup",
            sortOrder: 0
        )
        try meaningRepository.insert(meaning)

        let example = Example(
            id: "example-restore-0001",
            meaningID: meaning.id,
            en: "This is an instance of transfer learning.",
            ja: "これは転移学習の一例です。",
            sourcePDFID: pdf.id,
            sortOrder: 0
        )
        try exampleRepository.insert(example)

        let appearance = Appearance(
            id: "appearance-restore-0001",
            wordID: word.id,
            meaningID: meaning.id,
            pdfID: pdf.id,
            page: 3,
            bboxX: 12.5,
            bboxY: 18.0,
            bboxWidth: 41.0,
            bboxHeight: 11.0,
            contextSnippet: "The instance is highlighted in the paper.",
            addedAt: DateFormatting.iso8601String()
        )
        try appearanceRepository.insertAndRefreshCount(appearance, wordRepository: wordRepository)

        try DatabaseBackupExporter(paths: paths).export()
        try FileManager.default.removeItem(at: paths.databaseURL)

        _ = try DatabaseBootstrapper(paths: paths).prepareDatabase()

        database = try SQLiteDatabase(path: paths.databaseURL.path)
        folderRepository = FolderRepository(database: database)
        pdfRepository = PDFRepository(database: database)
        wordRepository = WordRepository(database: database)
        meaningRepository = MeaningRepository(database: database)
        exampleRepository = ExampleRepository(database: database)
        appearanceRepository = AppearanceRepository(database: database)

        let restoredFolders = try folderRepository.fetchAll()
        #expect(restoredFolders.contains(where: { $0.id == rootFolder.id && $0.parentID == nil }))
        #expect(restoredFolders.contains(where: { $0.id == childFolder.id && $0.parentID == rootFolder.id }))

        let restoredPDF = try pdfRepository.fetch(id: pdf.id)
        #expect(restoredPDF?.folderID == childFolder.id)
        #expect(restoredPDF?.filename == "clip.pdf")

        let restoredWord = try wordRepository.fetchBySurface("INSTANCE")
        #expect(restoredWord?.reading == "インスタンス")
        #expect(restoredWord?.totalCount == 1)

        let restoredMeanings = try meaningRepository.fetchAll(wordID: word.id)
        #expect(restoredMeanings.count == 1)
        #expect(restoredMeanings.first?.definition == "An example or case.")

        let restoredExamples = try exampleRepository.fetchAll(meaningID: meaning.id)
        #expect(restoredExamples.count == 1)
        #expect(restoredExamples.first?.sourcePDFID == pdf.id)

        let restoredAppearances = try appearanceRepository.fetchAll(wordID: word.id)
        #expect(restoredAppearances.count == 1)
        #expect(restoredAppearances.first?.pdfID == pdf.id)
        #expect(restoredAppearances.first?.page == 3)
    }
}
