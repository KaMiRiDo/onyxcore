import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/platform/disk_usage.dart';
import 'dart:isolate';

class CategoryStats {
  final int count;
  final int totalBytes;

  const CategoryStats({this.count = 0, this.totalBytes = 0});

  CategoryStats copyWith({int? count, int? totalBytes}) {
    return CategoryStats(
      count: count ?? this.count,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class DirectoryAnalysisResult {
  final String path;
  final int totalItems;
  final int totalBytes;
  final DiskUsage? diskUsage;
  final Map<FileItemType, CategoryStats> categoryStats;
  final List<FileStatWithInfo> topLargeFiles;

  const DirectoryAnalysisResult({
    required this.path,
    required this.totalItems,
    required this.totalBytes,
    required this.diskUsage,
    required this.categoryStats,
    required this.topLargeFiles,
  });
}

class FileStatWithInfo {
  final String path;
  final String name;
  final FileStat stat;
  final FileItemType type;

  const FileStatWithInfo({
    required this.path,
    required this.name,
    required this.stat,
    required this.type,
  });
}

class _AnalysisParams {
  final String path;
  final int topCount;

  _AnalysisParams(this.path, this.topCount);
}

Future<DirectoryAnalysisResult> _analyzeDirectoryInIsolate(_AnalysisParams params) async {
  final dir = Directory(params.path);
  if (!dir.existsSync()) {
    return DirectoryAnalysisResult(
      path: params.path,
      totalItems: 0,
      totalBytes: 0,
      diskUsage: null,
      categoryStats: {},
      topLargeFiles: [],
    );
  }

  int totalItems = 0;
  int totalBytes = 0;
  final Map<FileItemType, CategoryStats> stats = {
    FileItemType.image: const CategoryStats(),
    FileItemType.video: const CategoryStats(),
    FileItemType.audio: const CategoryStats(),
    FileItemType.document: const CategoryStats(),
    FileItemType.archive: const CategoryStats(),
    FileItemType.other: const CategoryStats(),
  };

  final List<FileStatWithInfo> largeFiles = [];

  void addLargeFile(FileStatWithInfo info) {
    if (largeFiles.length < params.topCount) {
      largeFiles.add(info);
      if (largeFiles.length == params.topCount) {
        largeFiles.sort((a, b) => b.stat.size.compareTo(a.stat.size));
      }
    } else {
      if (info.stat.size > largeFiles.last.stat.size) {
        largeFiles.removeLast();
        largeFiles.add(info);
        largeFiles.sort((a, b) => b.stat.size.compareTo(a.stat.size));
      }
    }
  }

  try {
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final stat = entity.statSync();
          final size = stat.size;
          totalItems++;
          totalBytes += size;

          final name = entity.uri.pathSegments.last;
          if (name.startsWith('.')) continue;

          final type = classifyFileType(name);
          final currentStat = stats[type]!;
          stats[type] = currentStat.copyWith(
            count: currentStat.count + 1,
            totalBytes: currentStat.totalBytes + size,
          );

          if (size > 1024 * 1024) { // Only track files > 1MB as candidates
            addLargeFile(FileStatWithInfo(
              path: entity.path,
              name: name,
              stat: stat,
              type: type,
            ));
          }
        } catch (_) {}
      }
    }
  } catch (_) {}

  largeFiles.sort((a, b) => b.stat.size.compareTo(a.stat.size));
  
  return DirectoryAnalysisResult(
    path: params.path,
    totalItems: totalItems,
    totalBytes: totalBytes,
    diskUsage: null, // Fetched outside isolate
    categoryStats: stats,
    topLargeFiles: largeFiles,
  );
}

class _IsolateMessage {
  final _AnalysisParams params;
  final SendPort sendPort;
  _IsolateMessage(this.params, this.sendPort);
}

void _isolateEntry(_IsolateMessage msg) async {
  final result = await _analyzeDirectoryInIsolate(msg.params);
  msg.sendPort.send(result);
}

final directoryAnalysisProvider = FutureProvider.autoDispose.family<DirectoryAnalysisResult, String>((ref, path) async {
  // 1. Get disk usage in main thread
  final diskUsage = await getDiskUsage(path);
  
  // 2. Spawn isolate for recursive traversal
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(_isolateEntry, _IsolateMessage(_AnalysisParams(path, 50), receivePort.sendPort));
  
  ref.onDispose(() {
    isolate.kill(priority: Isolate.immediate);
    receivePort.close();
  });
  
  final result = await receivePort.first as DirectoryAnalysisResult;
  isolate.kill();
  
  return DirectoryAnalysisResult(
    path: result.path,
    totalItems: result.totalItems,
    totalBytes: result.totalBytes,
    diskUsage: diskUsage,
    categoryStats: result.categoryStats,
    topLargeFiles: result.topLargeFiles,
  );
});
