import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_provider.dart';

/// A single entry in the task history.
class TaskHistoryEntry {
  final String id;
  final String title;
  final String subtitle;
  final String statusName;
  final String? errorMessage;
  final int processedCount;
  final int totalCount;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const TaskHistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusName,
    this.errorMessage,
    this.processedCount = 0,
    this.totalCount = 0,
    this.logs = const [],
    required this.createdAt,
    this.startedAt,
    this.completedAt,
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
      logs: List<String>.from(task.logs),
      createdAt: task.createdAt,
      startedAt: task.startedAt,
      completedAt: task.completedAt,
    );
  }

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TaskHistoryEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      statusName: json['statusName'] as String? ?? 'completed',
      errorMessage: json['errorMessage'] as String?,
      processedCount: json['processedCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      logs: (json['logs'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'statusName': statusName,
    'errorMessage': errorMessage,
    'processedCount': processedCount,
    'totalCount': totalCount,
    'logs': logs,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
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
  bool _isInitialized = false;

  @override
  List<TaskHistoryEntry> build() {
    _loadFromDisk();
    return [];
  }

  String get _historyFilePath {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.config/onyxcore/task_history.json';
  }

  bool get hasMore => _loadedCount < _allEntries.length;
  int get totalEntries => _allEntries.length;

  /// Load history from disk.
  void _loadFromDisk() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    try {
      final file = File(_historyFilePath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
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
    state = _allEntries.take(_loadedCount).toList();
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

  /// Persist to disk.
  void _saveToDisk() {
    try {
      final file = File(_historyFilePath);
      file.parent.createSync(recursive: true);
      final jsonList = _allEntries.map((e) => e.toJson()).toList();
      file.writeAsStringSync(jsonEncode(jsonList));
    } catch (e) {
      // Silently fail — don't crash the app for history persistence issues
    }
  }
}

final taskHistoryProvider =
    NotifierProvider<TaskHistoryNotifier, List<TaskHistoryEntry>>(
        TaskHistoryNotifier.new);
