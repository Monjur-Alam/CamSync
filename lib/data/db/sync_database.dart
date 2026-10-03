import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SyncDatabase {
  SyncDatabase._(this._db);

  final Database _db;

  Database get raw => _db;

  static Future<SyncDatabase> open() async {
    final directory = await getDatabasesPath();
    final db = await openDatabase(
      p.join(directory, 'misurl.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE images (
            client_image_id TEXT PRIMARY KEY,
            batch_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            bytes INTEGER NOT NULL,
            captured_at TEXT NOT NULL,
            status TEXT NOT NULL,
            attempt INTEGER NOT NULL DEFAULT 0,
            progress INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            error_code TEXT,
            remote_url TEXT,
            claimed_at INTEGER NOT NULL DEFAULT 0,
            next_attempt_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_images_status ON images(status, next_attempt_at, created_at)',
        );
        await database.execute(
          'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    return SyncDatabase._(db);
  }
}
