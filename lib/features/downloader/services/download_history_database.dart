import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart'
    as domain;

/// Drift-backed implementation of the download history database.
///
/// Replaces the old raw sqlite3 [DownloadHistoryDatabase]. Exposes the same
/// public interface so [DownloadHistoryNotifier] requires zero changes.
class DownloadHistoryDatabase {
  DownloadHistoryDatabase(this._db);

  final AppDatabase _db;

  /// No-op: Drift manages schema creation automatically.
  void init() {}

  /// No-op: Drift manages its own connection lifecycle.
  void dispose() {}

  Future<void> insertEntry(domain.DownloadHistoryEntry entry) async {
    await _db.upsertDownloadHistoryEntry(
      DownloadHistoryEntriesCompanion.insert(
        id: entry.id,
        title: entry.title,
        url: entry.url,
        destination: entry.destination,
        downloadType: entry.downloadType,
        statusName: entry.statusName,
        errorMessage: Value(entry.errorMessage),
        createdAt: entry.createdAt.millisecondsSinceEpoch,
        completedAt: Value(entry.completedAt?.millisecondsSinceEpoch),
        logs: Value(jsonEncode(entry.logs)),
      ),
    );
  }

  Future<List<domain.DownloadHistoryEntry>> getEntries({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _db.getDownloadHistoryPage(limit: limit, offset: offset);
    return rows.map(_entryFromRow).toList();
  }

  Future<int> getTotalCount() => _db.getDownloadHistoryCount();

  Future<domain.DownloadHistoryEntry?> getEntry(String id) async {
    final row = await _db.getDownloadHistoryEntry(id);
    if (row == null) return null;
    return _entryFromRow(row);
  }

  Future<void> deleteEntries(Set<String> ids) async {
    await _db.deleteDownloadHistoryEntries(ids);
  }

  Future<void> clearAll() async {
    await _db.clearAllDownloadHistory();
  }

  /// Returns 0 — file size tracking is no longer meaningful with a shared DB.
  int get fileSize => 0;

  domain.DownloadHistoryEntry _entryFromRow(DownloadHistoryEntry row) {
    final logsRaw = row.logs;
    final List<String> logs = logsRaw != null && logsRaw.isNotEmpty
        ? (jsonDecode(logsRaw) as List<dynamic>).map((e) => e.toString()).toList()
        : [];

    return domain.DownloadHistoryEntry(
      id: row.id,
      title: row.title,
      url: row.url,
      destination: row.destination,
      downloadType: row.downloadType,
      statusName: row.statusName,
      errorMessage: row.errorMessage,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      completedAt: row.completedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.completedAt!)
          : null,
      logs: logs,
    );
  }
}
