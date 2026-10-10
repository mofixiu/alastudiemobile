import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalStore {
  LocalStore._(this._db);
  final Database _db;

  static Future<LocalStore> open() async {
    final root = await getDatabasesPath();
    final db = await openDatabase(
      p.join(root, 'alastudie_local.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cache (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE outbox (id TEXT PRIMARY KEY, kind TEXT NOT NULL, path TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
      },
    );
    return LocalStore._(db);
  }

  Future<void> cacheJson(String key, Object value) async {
    await _db.insert('cache', {
      'key': key,
      'value': jsonEncode(value),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<dynamic> readJson(String key) async {
    final rows = await _db.query(
      'cache',
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['value']! as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> queue(
    String id,
    String kind,
    String path,
    Map<String, dynamic> payload,
  ) async {
    await _db.insert('outbox', {
      'id': id,
      'kind': kind,
      'path': path,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, Object?>>> pending() =>
      _db.query('outbox', orderBy: 'created_at');
  Future<void> removePending(String id) async {
    await _db.delete('outbox', where: 'id=?', whereArgs: [id]);
  }

  Future<void> clearUserCache() async {
    await _db.delete(
      'cache',
      where: 'key<>?',
      whereArgs: ['appearance:dark_mode'],
    );
    await _db.delete('outbox');
  }

  Future<void> close() => _db.close();
}
