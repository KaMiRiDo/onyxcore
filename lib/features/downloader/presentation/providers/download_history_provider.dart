import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'download_task_provider.dart';

class DownloadHistoryEntry {
  final String id;
  final String title;
  final String statusName;
  final String? errorMessage;
  final String url;
  final String destination;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadHistoryEntry({
    required this.id,
    required this.title,
    required this.statusName,
    this.errorMessage,
    required this.url,
    required this.destination,
    this.logs = const [],
    required this.createdAt,
    this.completedAt,
  });

  factory DownloadHistoryEntry.fromTask(DownloadTask task) {
    return DownloadHistoryEntry(
      id: task.id,
      title: task.title,
      statusName: task.status.name,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'statusName': statusName,
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
  List<DownloadHistoryEntry> _allEntries = [];
  int _loadedCount = 0;

  @override
  List<DownloadHistoryEntry> build() {
    return _loadFromDisk();
  }

  String get _historyFilePath {
    final home = io.Platform.environment['HOME'] ?? '/tmp';
    return '$home/.config/onyxcore/download_history.json';
  }

  bool get hasMore => _loadedCount < _allEntries.length;
  int get totalEntries => _allEntries.length;

  List<DownloadHistoryEntry> _loadFromDisk() {
    try {
      final file = io.File(_historyFilePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
        _allEntries = jsonList
            .map((e) => DownloadHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      _allEntries = [];
    }

    _loadedCount = _allEntries.length.clamp(0, _pageSize);
    return _allEntries.take(_loadedCount).toList();
  }

  void loadMore() {
    if (!hasMore) return;
    final newCount = (_loadedCount + _pageSize).clamp(0, _allEntries.length);
    _loadedCount = newCount;
    state = _allEntries.take(_loadedCount).toList();
  }

  void addEntry(DownloadTask task) {
    final entry = DownloadHistoryEntry.fromTask(task);
    _allEntries.insert(0, entry);
    _loadedCount++;
    state = _allEntries.take(_loadedCount).toList();
    _saveToDisk();
  }

  DownloadHistoryEntry? getEntry(String id) {
    try {
      return _allEntries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearAll() {
    _allEntries.clear();
    _loadedCount = 0;
    state = [];
    _saveToDisk();
  }

  void deleteEntries(Set<String> ids) {
    _allEntries.removeWhere((e) => ids.contains(e.id));
    _loadedCount = (_allEntries.length < _loadedCount) ? _allEntries.length : _loadedCount;
    state = _allEntries.take(_loadedCount).toList();
    _saveToDisk();
  }

  void deleteEntry(String id) {
    deleteEntries({id});
  }

  void _saveToDisk() {
    try {
      final file = io.File(_historyFilePath);
      file.parent.createSync(recursive: true);
      final jsonList = _allEntries.map((e) => e.toJson()).toList();
      file.writeAsStringSync(jsonEncode(jsonList));
    } catch (e) {
      // Silently fail
    }
  }

  int get historyFileSize {
    try {
      final file = io.File(_historyFilePath);
      if (file.existsSync()) return file.lengthSync();
    } catch (_) {}
    return 0;
  }

  void deleteFiltered(DownloadHistoryFilter filter) {
    _allEntries.removeWhere((entry) => _matchesFilter(entry, filter));
    _loadedCount = (_allEntries.length < _loadedCount) ? _allEntries.length : _loadedCount;
    state = _allEntries.take(_loadedCount).toList();
    _saveToDisk();
  }

  static bool _matchesFilter(DownloadHistoryEntry entry, DownloadHistoryFilter filter) {
    if (filter.isEmpty) return true;

    bool dateMatch = true;
    if (filter.selectedDates != null && filter.selectedDates!.isNotEmpty) {
      dateMatch = filter.selectedDates!.any((d) => 
        entry.createdAt.year == d.year && 
        entry.createdAt.month == d.month && 
        entry.createdAt.day == d.day
      );
    }

    bool opMatch = true;
    if (filter.status != null && filter.status != 'All') {
      opMatch = entry.statusName.toLowerCase() == filter.status!.toLowerCase();
    }

    return dateMatch && opMatch;
  }
}

class DownloadHistoryFilter {
  final Set<DateTime>? selectedDates;
  final String? status;

  const DownloadHistoryFilter({this.selectedDates, this.status});

  bool get isEmpty => (selectedDates == null || selectedDates!.isEmpty) && (status == null || status == 'All');

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

final downloadHistoryFilterProvider = StateProvider<DownloadHistoryFilter>((ref) => const DownloadHistoryFilter());

final availableDownloadDatesProvider = Provider<Set<DateTime>>((ref) {
  final history = ref.watch(downloadHistoryProvider);
  return history.map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day)).toSet();
});

final filteredDownloadHistoryProvider = Provider<List<DownloadHistoryEntry>>((ref) {
  final history = ref.watch(downloadHistoryProvider);
  final filter = ref.watch(downloadHistoryFilterProvider);

  if (filter.isEmpty) return history;

  return history.where((entry) => DownloadHistoryNotifier._matchesFilter(entry, filter)).toList();
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
        DownloadHistoryNotifier.new);

final downloadHistorySelectionProvider =
    NotifierProvider<DownloadHistorySelectionNotifier, Set<String>>(
        DownloadHistorySelectionNotifier.new);
