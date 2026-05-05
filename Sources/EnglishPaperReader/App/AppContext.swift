import Combine
import Foundation

@MainActor
final class AppContext: ObservableObject {
    let paths: AppPaths
    let database: SQLiteDatabase
    let folderRepository: FolderRepository
    let pdfRepository: PDFRepository
    let wordRepository: WordRepository
    let meaningRepository: MeaningRepository
    let exampleRepository: ExampleRepository
    let appearanceRepository: AppearanceRepository

    @Published var startupMessage: String?

    init(
        paths: AppPaths,
        database: SQLiteDatabase,
        folderRepository: FolderRepository,
        pdfRepository: PDFRepository,
        wordRepository: WordRepository,
        meaningRepository: MeaningRepository,
        exampleRepository: ExampleRepository,
        appearanceRepository: AppearanceRepository,
        startupMessage: String?
    ) {
        self.paths = paths
        self.database = database
        self.folderRepository = folderRepository
        self.pdfRepository = pdfRepository
        self.wordRepository = wordRepository
        self.meaningRepository = meaningRepository
        self.exampleRepository = exampleRepository
        self.appearanceRepository = appearanceRepository
        self.startupMessage = startupMessage
    }

    static func bootstrap() -> AppContext {
        do {
            let paths = try AppPaths.default()
            let bootstrapper = DatabaseBootstrapper(paths: paths)
            let bootstrapResult = try bootstrapper.prepareDatabase()
            let database = try SQLiteDatabase(path: paths.databaseURL.path)

            let folderRepository = FolderRepository(database: database)
            let pdfRepository = PDFRepository(database: database)
            let wordRepository = WordRepository(database: database)
            let meaningRepository = MeaningRepository(database: database)
            let exampleRepository = ExampleRepository(database: database)
            let appearanceRepository = AppearanceRepository(database: database)

            try pdfRepository.markMissingFiles()

            return AppContext(
                paths: paths,
                database: database,
                folderRepository: folderRepository,
                pdfRepository: pdfRepository,
                wordRepository: wordRepository,
                meaningRepository: meaningRepository,
                exampleRepository: exampleRepository,
                appearanceRepository: appearanceRepository,
                startupMessage: bootstrapResult.message
            )
        } catch {
            fatalError("Failed to bootstrap app: \(error)")
        }
    }
}
