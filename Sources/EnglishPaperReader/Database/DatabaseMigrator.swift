import Foundation

struct DatabaseMigrator {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func migrate() throws {
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS folders (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              parent_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS pdfs (
              id TEXT PRIMARY KEY,
              abs_path TEXT,
              filename TEXT NOT NULL,
              title TEXT,
              folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
              added_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS words (
              id TEXT PRIMARY KEY,
              surface TEXT NOT NULL,
              reading TEXT,
              total_count INTEGER NOT NULL DEFAULT 0,
              added_at TEXT NOT NULL
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_words_surface_ci
            ON words (lower(surface));

            CREATE TABLE IF NOT EXISTS meanings (
              id TEXT PRIMARY KEY,
              word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
              pos TEXT,
              definition TEXT NOT NULL,
              note TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS examples (
              id TEXT PRIMARY KEY,
              meaning_id TEXT NOT NULL REFERENCES meanings(id) ON DELETE CASCADE,
              en TEXT NOT NULL,
              ja TEXT,
              source_pdf_id TEXT REFERENCES pdfs(id) ON DELETE SET NULL,
              sort_order INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS appearances (
              id TEXT PRIMARY KEY,
              word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
              meaning_id TEXT REFERENCES meanings(id) ON DELETE SET NULL,
              pdf_id TEXT NOT NULL REFERENCES pdfs(id) ON DELETE CASCADE,
              page INTEGER NOT NULL,
              bbox_x REAL NOT NULL,
              bbox_y REAL NOT NULL,
              bbox_width REAL NOT NULL,
              bbox_height REAL NOT NULL,
              context_snippet TEXT,
              added_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_pdfs_folder_id ON pdfs(folder_id);
            CREATE INDEX IF NOT EXISTS idx_meanings_word_id ON meanings(word_id);
            CREATE INDEX IF NOT EXISTS idx_examples_meaning_id ON examples(meaning_id);
            CREATE INDEX IF NOT EXISTS idx_appearances_word_id ON appearances(word_id);
            CREATE INDEX IF NOT EXISTS idx_appearances_pdf_id ON appearances(pdf_id);
            """
        )
    }
}
