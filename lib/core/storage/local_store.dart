import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalStore {
  LocalStore._(this._db);
  final Database _db;

  static LocalStore? current;

  static Future<LocalStore> open() async {
    final root = await getDatabasesPath();
    final db = await openDatabase(
      p.join(root, 'alastudie_local.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cache (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE outbox (id TEXT PRIMARY KEY, kind TEXT NOT NULL, path TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)',
        );
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          // v2 keeps the existing cache/outbox intact; durable nearby-session
          // snapshots and stable peer IDs live in the existing JSON cache.
          await db.execute(
            'CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS outbox (id TEXT PRIMARY KEY, kind TEXT NOT NULL, path TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
        }
      },
    );
    final store = LocalStore._(db);
    current = store;
    return store;
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

  Future<void> removeCache(String key) async {
    await _db.delete('cache', where: 'key=?', whereArgs: [key]);
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

  Future<List<Map<String, Object?>>> pending() async {
    await _db.delete(
      'outbox',
      where: "kind='nearby_summary' AND created_at<?",
      whereArgs: [
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      ],
    );
    return _db.query('outbox', orderBy: 'created_at');
  }

  Future<void> removePending(String id) async {
    await _db.delete('outbox', where: 'id=?', whereArgs: [id]);
  }

  Future<void> clearUserCache() async {
    await _db.delete(
      'cache',
      where: 'key<>?',
      whereArgs: ['appearance:dark_mode'],
    );
    await _db.delete('outbox', where: "kind<>'nearby_summary'");
  }

  Future<void> close() => _db.close();
}
