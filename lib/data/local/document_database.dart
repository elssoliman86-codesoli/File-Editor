import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DocumentDatabase {
  Database? _database;

  Future<Database> get instance async {
    if (_database != null) return _database!;
    final root = await getApplicationSupportDirectory();
    await root.create(recursive: true);
    _database = await openDatabase(
      p.join(root.path, 'midad.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            original_path TEXT NOT NULL,
            payload_path TEXT NOT NULL,
            last_opened INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            favorite INTEGER NOT NULL DEFAULT 0,
            dirty INTEGER NOT NULL DEFAULT 1,
            encoding TEXT NOT NULL DEFAULT 'utf-8',
            eol TEXT NOT NULL DEFAULT 'LF',
            source_uri TEXT,
            last_saved_hash TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX documents_recent ON documents(last_opened DESC)',
        );
        await db.execute('''
          CREATE TABLE reading_positions (
            document_id TEXT PRIMARY KEY,
            page INTEGER NOT NULL,
            zoom REAL NOT NULL DEFAULT 1,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
          )
        ''');
      },
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
