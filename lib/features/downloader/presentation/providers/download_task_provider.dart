import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

enum DownloadStatus { pending, running, completed, error, cancelled }

class DownloadTask {
  final String id;
  final String url;
  final String destination;
  final String title;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String speed;
  final String eta;
  final String totalSize;
  final String? error;
  final Process? process;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.destination,
    required this.title,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speed = '',
    this.eta = '',
    this.totalSize = '',
    this.error,
    this.process,
    this.logs = const [],
    required this.createdAt,
    this.completedAt,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    String? speed,
    String? eta,
    String? totalSize,
    String? error,
    Process? process,
    List<String>? logs,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      destination: destination,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      totalSize: totalSize ?? this.totalSize,
      error: error ?? this.error,
      process: process ?? this.process,
      logs: logs ?? this.logs,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class DownloadTaskNotifier extends Notifier<List<DownloadTask>>
    with WindowListener {
  final _uuid = const Uuid();

  @override
  List<DownloadTask> build() {
    windowManager.addListener(this);
    ref.onDispose(() {
      windowManager.removeListener(this);
    });
    return [];
  }

  @override
  void onWindowClose() {
    // Zombie Process Prevention
    for (final task in state) {
      if (task.status == DownloadStatus.running && task.process != null) {
        Process.killPid(task.process!.pid, ProcessSignal.sigkill);
      }
    }
  }

  void startDownload({
    required String url,
    required String destination,
    required String title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String engine = 'auto',
    bool isPlaylist = false,
  }) async {
    final id = _uuid.v4();
    final newTask = DownloadTask(
      id: id,
      url: url,
      destination: destination,
      title: title,
      status: DownloadStatus.running,
      createdAt: DateTime.now(),
    );

    state = [...state, newTask];

    try {
      final browser = ref.read(settingsProvider).value?.downloadBrowser;
      final process = await MediaDownloaderBackend.startDownload(
        url: url,
        destination: destination,
        title: title,
        format: format,
        audioOnly: audioOnly,
        mute: mute,
        galleryIndex: galleryIndex,
        engine: engine,
        isPlaylist: isPlaylist,
        browser: browser,
      );

      _updateTask(id, process: process);

      process.stdout.transform(utf8.decoder).listen((data) {
        _parseProgress(id, data);
        _appendLog(id, data);
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        _appendLog(id, data);
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        _updateTask(id, status: DownloadStatus.completed, progress: 1.0, completedAt: DateTime.now());
      } else {
        // Only mark as error if it wasn't cancelled
        final currentTask = state.firstWhere((t) => t.id == id);
        if (currentTask.status != DownloadStatus.cancelled) {
          _updateTask(id,
              status: DownloadStatus.error,
              error: 'Process exited with code $exitCode',
              completedAt: DateTime.now());
        }
      }
    } catch (e) {
      _updateTask(id, status: DownloadStatus.error, error: e.toString(), completedAt: DateTime.now());
    }
  }

  void cancelDownload(String id) {
    try {
        final task = state.firstWhere((t) => t.id == id);
        if (task.status == DownloadStatus.running && task.process != null) {
          Process.killPid(task.process!.pid, ProcessSignal.sigkill);
        }
        _updateTask(id, status: DownloadStatus.cancelled, completedAt: DateTime.now());
    } catch (_) {}
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void clearHistory() {
     state = state.where((t) => t.status == DownloadStatus.running || t.status == DownloadStatus.pending).toList();
  }

  final Map<String, Timer> _removalTimers = {};

  void _startAutoRemovalTimer(String id) {
    if (_removalTimers.containsKey(id)) return;

    _removalTimers[id] = Timer(const Duration(seconds: 3), () {
      final task = state.where((t) => t.id == id).firstOrNull;
      if (task != null && (task.status == DownloadStatus.completed || task.status == DownloadStatus.error || task.status == DownloadStatus.cancelled)) {
        ref.read(downloadHistoryProvider.notifier).addEntry(task);
        removeTask(id);
      }
      _removalTimers.remove(id);
    });
  }

  void _updateTask(String id,
      {DownloadStatus? status,
      double? progress,
      String? speed,
      String? eta,
      String? totalSize,
      String? error,
      Process? process,
      DateTime? completedAt}) {
    state = state.map((task) {
      if (task.id == id) {
        final updated = task.copyWith(
          status: status,
          progress: progress,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          error: error,
          process: process,
          completedAt: completedAt,
        );
        if (status == DownloadStatus.completed || status == DownloadStatus.error || status == DownloadStatus.cancelled) {
          _startAutoRemovalTimer(id);
        }
        return updated;
      }
      return task;
    }).toList();
  }

  void _appendLog(String id, String data) {
    state = state.map((task) {
      if (task.id == id) {
        final newLogs = List<String>.from(task.logs);
        // Only add non-empty trimmed lines
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            newLogs.add(line.trim());
          }
        }
        return task.copyWith(logs: newLogs);
      }
      return task;
    }).toList();
  }

  void _parseProgress(String id, String data) {
    // Handle standard yt-dlp output
    final RegExp progressRegExp = RegExp(
        r'\[download\]\s+([\d\.]+)\%\s+of\s+(.*?)\s+at\s+(.*?)\s+ETA\s+(.*)');
    final match = progressRegExp.firstMatch(data);

    if (match != null) {
      final percentage = double.tryParse(match.group(1) ?? '0.0') ?? 0.0;
      final size = match.group(2) ?? '';
      final speed = match.group(3) ?? '';
      final eta = match.group(4) ?? '';

      _updateTask(id,
          progress: percentage / 100.0, speed: speed.trim(), eta: eta.trim(), totalSize: size.trim());
      return;
    }

    // Handle aria2c output if injected
    final RegExp ariaRegExp = RegExp(r'\[.*?\((\d+)%\).*?DL:(.*?) ETA:(.*?)\]');
    final ariaMatch = ariaRegExp.firstMatch(data);
    if (ariaMatch != null) {
      final percentage = double.tryParse(ariaMatch.group(1) ?? '0.0') ?? 0.0;
      final speed = ariaMatch.group(2) ?? '';
      final eta = ariaMatch.group(3) ?? '';
      _updateTask(id,
          progress: percentage / 100.0, speed: speed.trim(), eta: eta.trim());
    }
  }
}

final downloadTaskProvider =
    NotifierProvider<DownloadTaskNotifier, List<DownloadTask>>(DownloadTaskNotifier.new);

final activeDownloadTaskProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadTaskProvider);
  return tasks
      .where((t) =>
          t.status == DownloadStatus.running ||
          t.status == DownloadStatus.pending)
      .toList();
});

final completedDownloadTaskProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadTaskProvider);
  return tasks
      .where((t) =>
          t.status == DownloadStatus.completed ||
          t.status == DownloadStatus.error ||
          t.status == DownloadStatus.cancelled)
      .toList();
});
