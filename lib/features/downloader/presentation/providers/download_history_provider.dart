import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/services/download_history_database.dart';

class DownloadHistoryEntry {

  const DownloadHistoryEntry({
    required this.id,
    required this.title,
    required this.statusName,
    required this.url, required this.destination, required this.createdAt, this.downloadType = 'generic',
    this.errorMessage,
    this.logs = const [],
    this.completedAt,
  });

  factory DownloadHistoryEntry.fromTask(DownloadTask task) {
    return DownloadHistoryEntry(
      id: task.id,
      title: task.title,
      statusName: task.status.name,
      downloadType: task.downloadType,
      errorMessage: task.error,
      url: task.url,
      destination: task.destination,
      logs: List<String>.from(task.logs),
      createdAt: task.createdAt,
      completedAt: task.completedAt,
    );
  }

  factory DownloadHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DownloadHistoryEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Download',
      statusName: json['statusName']?.toString() ?? 'completed',
      downloadType: json['downloadType']?.toString() ?? 'generic',
      errorMessage: json['errorMessage']?.toString(),
      url: json['url']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      logs: (json['logs'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
  final String id;
  final String title;
  final String statusName;
  final String downloadType;
  final String? errorMessage;
  final String url;
  final String destination;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'statusName': statusName,
    'downloadType': downloadType,
    'errorMessage': errorMessage,
    'url': url,
    'destination': destination,
    'logs': logs,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  Duration? get duration {
    if (completedAt == null) return null;
    return completedAt!.difference(createdAt);
  }
}

class DownloadHistoryNotifier extends Notifier<List<DownloadHistoryEntry>> {
  static const int _pageSize = 50;
  late final DownloadHistoryDatabase _db;
  List<DownloadHistoryEntry> _currentEntries = [];
  int _loadedCount = 0;

  bool _isDisposed = false;

  @override
  List<DownloadHistoryEntry> build() {
    ref.onDispose(() => _isDisposed = true);
    _db = DownloadHistoryDatabase(ref.read(databaseProvider));
    _db.init();
    // Note: No AppDatabase close needed — its lifecycle is managed by main.dart
    _loadInitialAsync();
    return [];
  }

  Future<void> _loadInitialAsync() async {
    _loadedCount = _pageSize;
    _currentEntries = await _db.getEntries(limit: _loadedCount);
    await _refreshTotal();
    if (_isDisposed) return;
    state = List.from(_currentEntries);
  }

  bool get hasMore => _loadedCount < (_totalCount ?? 0);
  int? _totalCount;
  int get totalEntries => _totalCount ?? 0;

  Future<void> _refreshTotal() async {
    _totalCount = await _db.getTotalCount();
  }

  List<DownloadHistoryEntry> _loadInitial() {
    _loadedCount = _pageSize;
    return [];
  }

  Future<void> loadMore() async {
    if (!hasMore) return;
    final additional = await _db.getEntries(offset: _loadedCount);
    _loadedCount += additional.length;
    _currentEntries.addAll(additional);
    state = List.from(_currentEntries);
  }

  Future<void> addEntry(DownloadTask task) async {
    final entry = DownloadHistoryEntry.fromTask(task);
    await _db.insertEntry(entry);
    await _refreshTotal();

    // Update local state without full reload if it's already at top
    _currentEntries.insert(0, entry);
    _loadedCount++;
    state = List.from(_currentEntries);
  }

  Future<DownloadHistoryEntry?> getEntry(String id) => _db.getEntry(id);

  Future<void> clearAll() async {
    await _db.clearAll();
    _totalCount = 0;
    _currentEntries.clear();
    _loadedCount = 0;
    state = [];
  }

  Future<void> deleteEntries(Set<String> ids) async {
    await _db.deleteEntries(ids);
    _currentEntries.removeWhere((e) => ids.contains(e.id));
    _loadedCount -= ids.length;
    if (_loadedCount < 0) _loadedCount = 0;
    await _refreshTotal();
    state = List.from(_currentEntries);
  }

  Future<void> deleteEntry(String id) => deleteEntries({id});

  int get historyFileSize => 0;

  Future<void> deleteFiltered(DownloadHistoryFilter filter) async {
    final allItems = await _db.getEntries(limit: 9999999);
    final toDelete = allItems
        .where((entry) => _matchesFilter(entry, filter))
        .map((e) => e.id)
        .toSet();
    await deleteEntries(toDelete);
  }

  static bool _matchesFilter(
    DownloadHistoryEntry entry,
    DownloadHistoryFilter filter,
  ) {
    if (filter.isEmpty) return true;

    var dateMatch = true;
    if (filter.selectedDates != null && filter.selectedDates!.isNotEmpty) {
      dateMatch = filter.selectedDates!.any(
        (d) =>
            entry.createdAt.year == d.year &&
            entry.createdAt.month == d.month &&
            entry.createdAt.day == d.day,
      );
    }

    var opMatch = true;
    if (filter.status != null && filter.status != 'All') {
      opMatch = entry.statusName.toLowerCase() == filter.status!.toLowerCase();
    }

    return dateMatch && opMatch;
  }
}

class DownloadHistoryFilter {

  const DownloadHistoryFilter({this.selectedDates, this.status});
  final Set<DateTime>? selectedDates;
  final String? status;

  bool get isEmpty =>
      (selectedDates == null || selectedDates!.isEmpty) &&
      (status == null || status == 'All');

  DownloadHistoryFilter copyWith({
    Set<DateTime>? selectedDates,
    String? status,
  }) {
    return DownloadHistoryFilter(
      selectedDates: selectedDates ?? this.selectedDates,
      status: status ?? this.status,
    );
  }
}

final downloadHistoryFilterProvider = StateProvider<DownloadHistoryFilter>(
  (ref) => const DownloadHistoryFilter(),
);

final availableDownloadDatesProvider = Provider<Set<DateTime>>((ref) {
  final history = ref.watch(downloadHistoryProvider);
  return history
      .map(
        (e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day),
      )
      .toSet();
});

final filteredDownloadHistoryProvider = Provider<List<DownloadHistoryEntry>>((
  ref,
) {
  final history = ref.watch(downloadHistoryProvider);
  final filter = ref.watch(downloadHistoryFilterProvider);

  if (filter.isEmpty) return history;

  return history
      .where((entry) => DownloadHistoryNotifier._matchesFilter(entry, filter))
      .toList();
});

class DownloadHistorySelectionNotifier extends Notifier<Set<String>> {
  String? _lastSelectedId;

  @override
  Set<String> build() => {};

  void setAnchor(String id) {
    _lastSelectedId = id;
  }

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
      if (_lastSelectedId == id) _lastSelectedId = null;
    } else {
      next.add(id);
      _lastSelectedId = id;
    }
    state = next;
  }

  void selectRange(List<DownloadHistoryEntry> entries, String targetId) {
    if (_lastSelectedId == null) {
      toggle(targetId);
      return;
    }

    final startIndex = entries.indexWhere((e) => e.id == _lastSelectedId);
    final endIndex = entries.indexWhere((e) => e.id == targetId);

    if (startIndex == -1 || endIndex == -1) {
      toggle(targetId);
      return;
    }

    final next = Set<String>.from(state);
    final min = startIndex < endIndex ? startIndex : endIndex;
    final max = startIndex < endIndex ? endIndex : startIndex;

    for (var i = min; i <= max; i++) {
      next.add(entries[i].id);
    }

    state = next;
    _lastSelectedId = targetId;
  }

  void clear() {
    state = {};
    _lastSelectedId = null;
  }
}

final downloadHistoryProvider =
    NotifierProvider<DownloadHistoryNotifier, List<DownloadHistoryEntry>>(
      DownloadHistoryNotifier.new,
    );

final downloadHistorySelectionProvider =
    NotifierProvider<DownloadHistorySelectionNotifier, Set<String>>(
      DownloadHistorySelectionNotifier.new,
    );
