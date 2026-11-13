import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../database/app_database.dart';
import '../models/recording.dart';

/// CRUD access to recording metadata. Knows nothing about audio files.
class RecordingRepository {
  RecordingRepository(this._db);

  final AppDatabase _db;

  static const String _table = AppConstants.recordingsTable;

  /// All recordings, newest first.
  Future<List<Recording>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map(Recording.fromMap).toList();
  }

  Future<Recording?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Recording.fromMap(rows.first);
  }

  Future<void> insert(Recording recording) async {
    final db = await _db.database;
    await db.insert(
      _table,
      recording.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Recording recording) async {
    final db = await _db.database;
    await db.update(
      _table,
      recording.toMap(),
      where: 'id = ?',
      whereArgs: [recording.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
