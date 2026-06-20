import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:flutter/foundation.dart';

class DownloadHistoryDatabase {
  late final Database _db;

  late final String _dbPath;
  late final String _legacyJsonPath;
  
  static final String _testSuffix = DateTime.now().microsecondsSinceEpoch.toString();

  @visibleForTesting
  static String get testDbPath => p.join(Directory.systemTemp.path, 'onyxcore_test', 'download_history_$_testSuffix.sqlite');

  @visibleForTesting
  static String get testLegacyJsonPath => p.join(Directory.systemTemp.path, 'onyxcore_test', 'download_history_$_testSuffix.json');

  DownloadHistoryDatabase() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _dbPath = testDbPath;
      _legacyJsonPath = testLegacyJsonPath;
    } else {
      final home = Platform.environment['HOME'] ?? '/tmp';
      _dbPath = p.join(home, '.config', 'onyxcore', 'download_history.sqlite');
      _legacyJsonPath = p.join(home, '.config', 'onyxcore', 'download_history.json');
    }
  }

  void init() {
    final file = File(_dbPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    _db = sqlite3.open(_dbPath);

    _db.execute('''
      CREATE TABLE IF NOT EXISTS history (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        statusName TEXT NOT NULL,
        downloadType TEXT NOT NULL,
        errorMessage TEXT,
        url TEXT NOT NULL,
        destination TEXT NOT NULL,
        logs TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        completedAt TEXT
      )
    ''');

    _migrateLegacyData();
  }

  void _migrateLegacyData() {
    try {
      final legacyFile = File(_legacyJsonPath);
      if (legacyFile.existsSync()) {
        final content = legacyFile.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;

        final stmt = _db.prepare('''
          INSERT OR IGNORE INTO history (
            id, title, statusName, downloadType, errorMessage, 
            url, destination, logs, createdAt, completedAt
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''');

        for (final item in jsonList) {
          final entry = DownloadHistoryEntry.fromJson(
            item as Map<String, dynamic>,
          );
          stmt.execute([
            entry.id,
            entry.title,
            entry.statusName,
            entry.downloadType,
            entry.errorMessage,
            entry.url,
            entry.destination,
            jsonEncode(entry.logs),
            entry.createdAt.toIso8601String(),
            entry.completedAt?.toIso8601String(),
          ]);
        }
        stmt.dispose();

        // Delete or rename legacy file
        legacyFile.renameSync('${_legacyJsonPath}.migrated');
      }
    } catch (e) {
      debugPrint('Migration failed: $e');
    }
  }

  void insertEntry(DownloadHistoryEntry entry) {
    final stmt = _db.prepare('''
      INSERT OR REPLACE INTO history (
        id, title, statusName, downloadType, errorMessage, 
        url, destination, logs, createdAt, completedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      entry.id,
      entry.title,
      entry.statusName,
      entry.downloadType,
      entry.errorMessage,
      entry.url,
      entry.destination,
      jsonEncode(entry.logs),
      entry.createdAt.toIso8601String(),
      entry.completedAt?.toIso8601String(),
    ]);
    stmt.dispose();
  }

  List<DownloadHistoryEntry> getEntries({int limit = 50, int offset = 0}) {
    final resultSet = _db.select(
      'SELECT * FROM history ORDER BY createdAt DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return resultSet.map((row) => _entryFromRow(row)).toList();
  }

  int getTotalCount() {
    final resultSet = _db.select('SELECT COUNT(*) as count FROM history');
    return resultSet.first['count'] as int;
  }

  DownloadHistoryEntry? getEntry(String id) {
    final resultSet = _db.select('SELECT * FROM history WHERE id = ?', [id]);
    if (resultSet.isNotEmpty) {
      return _entryFromRow(resultSet.first);
    }
    return null;
  }

  void deleteEntries(Set<String> ids) {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    _db.execute(
      'DELETE FROM history WHERE id IN ($placeholders)',
      ids.toList(),
    );
  }

  void clearAll() {
    _db.execute('DELETE FROM history');
    _db.execute('VACUUM');
  }

  int get fileSize {
    final file = File(_dbPath);
    if (file.existsSync()) return file.lengthSync();
    return 0;
  }

  void dispose() {
    _db.dispose();
  }

  DownloadHistoryEntry _entryFromRow(Row row) {
    return DownloadHistoryEntry(
      id: row['id'] as String,
      title: row['title'] as String,
      statusName: row['statusName'] as String,
      downloadType: row['downloadType'] as String,
      errorMessage: row['errorMessage'] as String?,
      url: row['url'] as String,
      destination: row['destination'] as String,
      logs: (jsonDecode(row['logs'] as String) as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(row['createdAt'] as String),
      completedAt: row['completedAt'] != null
          ? DateTime.parse(row['completedAt'] as String)
          : null,
    );
  }
}
