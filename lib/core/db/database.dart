// Local database. SQLite (bundled via sqlite3_flutter_libs, so FTS5 is always
// available on iOS). Raw SQL instead of an ORM: no code generation step, and the
// schema is small enough to read in one screen. See docs/DECISION_LOG.md ADR-003.
import 'package:sqlite3/sqlite3.dart';

const int kSchemaVersion = 1;

Database openTibbDatabase(String path) {
  final db = sqlite3.open(path);
  db.execute('PRAGMA journal_mode = WAL;');
  db.execute('PRAGMA foreign_keys = OFF;'); // integrity is enforced by the change log
  _migrate(db);
  return db;
}

/// In-memory database for tests.
Database openInMemoryTibbDatabase() {
  final db = sqlite3.openInMemory();
  _migrate(db);
  return db;
}

void _migrate(Database db) {
  final version = db.userVersion;
  if (version < 1) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
      CREATE TABLE IF NOT EXISTS devices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        platform TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS boxes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL,
        color TEXT NOT NULL,
        locked INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      );
      CREATE TABLE IF NOT EXISTS items (
        id TEXT PRIMARY KEY,
        box_id TEXT NOT NULL,
        type TEXT NOT NULL,
        text TEXT,
        blob_hash TEXT,
        mime TEXT,
        file_name TEXT,
        size INTEGER,
        duration_ms INTEGER,
        note TEXT,
        pinned INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        reviewed INTEGER NOT NULL DEFAULT 0,
        source TEXT,
        origin_device_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        expires_at INTEGER
      );
      CREATE INDEX IF NOT EXISTS items_by_box ON items (box_id, archived, created_at);
      CREATE TABLE IF NOT EXISTS blobs (
        hash TEXT PRIMARY KEY,
        mime TEXT,
        size INTEGER,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS changes (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        id TEXT NOT NULL UNIQUE,
        device_id TEXT NOT NULL,
        counter INTEGER NOT NULL,
        ts INTEGER NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload TEXT NOT NULL
      );
      CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
        item_id UNINDEXED,
        content,
        tokenize = 'unicode61 remove_diacritics 2'
      );
    ''');
    db.userVersion = 1;
  }
  // Future migrations: `if (version < 2) { ...; db.userVersion = 2; }`
}
