import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// Opens (and lazily creates) the local SQLite database.
class AppDatabase {
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, AppConstants.dbName),
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${AppConstants.recordingsTable} (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            original_path TEXT NOT NULL,
            processed_path TEXT,
            duration_ms INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            source TEXT NOT NULL,
            error_message TEXT
          )
        ''');
      },
    );
  }
}
