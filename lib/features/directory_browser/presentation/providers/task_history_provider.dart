import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

/// A single entry in the task history.
class TaskHistoryEntry {

  const TaskHistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusName,
    required this.createdAt, this.errorMessage,
    this.processedCount = 0,
    this.totalCount = 0,
    this.processedSizeBytes = 0,
    this.totalSizeBytes = 0,
    this.logs = const [],
    this.startedAt,
    this.completedAt,
    this.sourcePaths,
    this.targetPath,
  });

  factory TaskHistoryEntry.fromTask(FileTask task) {
    return TaskHistoryEntry(
      id: task.id,
      title: task.title,
      subtitle: task.subtitle,
      statusName: task.status.name,
      errorMessage: task.errorMessage,
      processedCount: task.processedCount,
      totalCount: task.totalCount,
      processedSizeBytes: task.processedSizeBytes,
      totalSizeBytes: task.totalSizeBytes,
      logs: List<String>.from(task.logs),
      createdAt: task.createdAt,
      startedAt: task.startedAt,
      completedAt: task.completedAt,
      sourcePaths: task.sourcePaths,
      targetPath: task.targetPath,
    );
  }

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TaskHistoryEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Task',
      subtitle: json['subtitle']?.toString() ?? '',
      statusName: json['statusName']?.toString() ?? 'completed',
      errorMessage: json['errorMessage']?.toString(),
      processedCount: (json['processedCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      processedSizeBytes: (json['processedSizeBytes'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (json['totalSizeBytes'] as num?)?.toInt() ?? 0,
      logs: (json['logs'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      sourcePaths: (json['sourcePaths'] as List<dynamic>?)?.cast<String>(),
      targetPath: json['targetPath'] as String?,
    );
  }
  final String id;
  final String title;
  final String subtitle;
  final String statusName;
  final String? errorMessage;
  final int processedCount;
  final int totalCount;
  final int? processedSizeBytes;
  final int? totalSizeBytes;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String>? sourcePaths;
  final String? targetPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'statusName': statusName,
    'errorMessage': errorMessage,
    'processedCount': processedCount,
    'totalCount': totalCount,
    'processedSizeBytes': processedSizeBytes,
    'totalSizeBytes': totalSizeBytes,
    'logs': logs,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'sourcePaths': sourcePaths,
    'targetPath': targetPath,
  };

  /// Duration of the task.
  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }
}

/// Manages persistent task history with lazy loading.
class TaskHistoryNotifier extends Notifier<List<TaskHistoryEntry>> {
  static const int _pageSize = 50;
  List<TaskHistoryEntry> _allEntries = [];
  int _loadedCount = 0;

  @override
  List<TaskHistoryEntry> build() {
    return _loadFromDisk();
  }

  String get _historyFilePath {
    final home = io.Platform.environment['HOME'] ?? '/tmp';
    return '$home/.config/onyxcore/task_history.json';
  }

  bool get hasMore => _loadedCount < _allEntries.length;
  int get totalEntries => _allEntries.length;

  /// Load history from disk.
  List<TaskHistoryEntry> _loadFromDisk() {
    try {
      final file = io.File(_historyFilePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final jsonList = jsonDecode(content) as List<dynamic>;
        _allEntries = jsonList
            .map((e) => TaskHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        // Sort newest first
        _allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      _allEntries = [];
    }

    // Load first page
    _loadedCount = _allEntries.length.clamp(0, _pageSize);
    return _allEntries.take(_loadedCount).toList();
  }

  /// Load the next page of history items.
  void loadMore() {
    if (!hasMore) return;
    final newCount = (_loadedCount + _pageSize).clamp(0, _allEntries.length);
    _loadedCount = newCount;
    state = _allEntries.take(_loadedCount).toList();
  }

  /// Add a completed task to history and persist.
  void addEntry(FileTask task) {
    final entry = TaskHistoryEntry.fromTask(task);
    _allEntries.insert(0, entry);
    _loadedCount++;
    state = _allEntries.take(_loadedCount).toList();
    _saveToDisk();
  }

  /// Get a specific entry by ID.
  TaskHistoryEntry? getEntry(String id) {
    try {
      return _allEntries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Clear all history permanently.
  void clearAll() {
    _allEntries.clear();
    _loadedCount = 0;
    state = [];
    _saveToDisk();
  }

  /// Delete specific entries by ID.
  void deleteEntries(Set<String> ids) {
    _allEntries.removeWhere((e) => ids.contains(e.id));
    _loadedCount = (_allEntries.length < _loadedCount)
        ? _allEntries.length
        : _loadedCount;
    state = _allEntries.take(_loadedCount).toList();
    _saveToDisk();
  }

  /// Delete a single entry by ID.
  void deleteEntry(String id) {
    deleteEntries({id});
  }

  /// Persist to disk.
  void _saveToDisk() {
    try {
      final file = io.File(_historyFilePath);
      file.parent.createSync(recursive: true);
      final jsonList = _allEntries.map((e) => e.toJson()).toList();
      file.writeAsStringSync(jsonEncode(jsonList));
    } catch (e) {
      // Silently fail — don't crash the app for history persistence issues
    }
  }

  int get historyFileSize {
    try {
      final file = io.File(_historyFilePath);
      if (file.existsSync()) return file.lengthSync();
    } catch (_) {}
    return 0;
  }

  /// Delete entries matching filter
  void deleteFiltered(TaskHistoryFilter filter) {
    _allEntries.removeWhere((entry) => _matchesFilter(entry, filter));
    _loadedCount = (_allEntries.length < _loadedCount)
        ? _allEntries.length
        : _loadedCount;
    state = _allEntries.take(_loadedCount).toList();
    _saveToDisk();
  }

  static bool _matchesFilter(TaskHistoryEntry entry, TaskHistoryFilter filter) {
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
    if (filter.operationType != null && filter.operationType != 'All') {
      final t = entry.title.toLowerCase();
      final op = filter.operationType!.toLowerCase();
      if (op == 'rename') {
        opMatch = t.contains('renam');
      } else if (op == 'delete') {
        opMatch = t.contains('delet') || t.contains('trash');
      } else if (op == 'copy') {
        opMatch = t.contains('copy');
      } else if (op == 'move') {
        opMatch = t.contains('mov');
      } else if (op == 'create') {
        opMatch = t.contains('new');
      }
    }

    return dateMatch && opMatch;
  }
}

class TaskHistoryFilter {

  const TaskHistoryFilter({this.selectedDates, this.operationType});
  final Set<DateTime>? selectedDates;
  final String? operationType;

  bool get isEmpty =>
      (selectedDates == null || selectedDates!.isEmpty) &&
      (operationType == null || operationType == 'All');

  TaskHistoryFilter copyWith({
    Set<DateTime>? selectedDates,
    String? operationType,
  }) {
    return TaskHistoryFilter(
      selectedDates: selectedDates ?? this.selectedDates,
      operationType: operationType ?? this.operationType,
    );
  }
}

final taskHistoryFilterProvider = StateProvider<TaskHistoryFilter>(
  (ref) => const TaskHistoryFilter(),
);

final availableDatesProvider = Provider<Set<DateTime>>((ref) {
  final history = ref.watch(taskHistoryProvider);
  return history
      .map(
        (e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day),
      )
      .toSet();
});

final filteredTaskHistoryProvider = Provider<List<TaskHistoryEntry>>((ref) {
  final history = ref.watch(taskHistoryProvider);
  final filter = ref.watch(taskHistoryFilterProvider);

  if (filter.isEmpty) return history;

  return history
      .where((entry) => TaskHistoryNotifier._matchesFilter(entry, filter))
      .toList();
});

/// Manages selection state for history items.
class HistorySelectionNotifier extends Notifier<Set<String>> {
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

  void selectRange(List<TaskHistoryEntry> entries, String targetId) {
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

final taskHistoryProvider =
    NotifierProvider<TaskHistoryNotifier, List<TaskHistoryEntry>>(
      TaskHistoryNotifier.new,
    );

/// Set of selected history item IDs for multi-delete.
final historySelectionProvider =
    NotifierProvider<HistorySelectionNotifier, Set<String>>(
      HistorySelectionNotifier.new,
    );
