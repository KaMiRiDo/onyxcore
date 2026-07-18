import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/core/platform/disk_usage.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class CategoryStats {

  const CategoryStats({this.count = 0, this.totalBytes = 0});
  final int count;
  final int totalBytes;

  CategoryStats copyWith({int? count, int? totalBytes}) {
    return CategoryStats(
      count: count ?? this.count,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class DirectoryAnalysisResult {

  const DirectoryAnalysisResult({
    required this.path,
    required this.totalItems,
    required this.totalBytes,
    required this.diskUsage,
    required this.categoryStats,
    required this.allFiles,
  });
  final String path;
  final int totalItems;
  final int totalBytes;
  final DiskUsage? diskUsage;
  final Map<FileItemType, CategoryStats> categoryStats;
  final List<FileStatWithInfo> allFiles;
}

class FileStatData {

  const FileStatData({
    required this.size,
    required this.modified,
  });
  final int size;
  final DateTime modified;
}

class FileStatWithInfo {

  const FileStatWithInfo({
    required this.path,
    required this.name,
    required this.stat,
    required this.type,
  });
  final String path;
  final String name;
  final FileStatData stat;
  final FileItemType type;
}

class _AnalysisParams {

  _AnalysisParams(this.path, this.sendPort);
  final String path;
  final SendPort sendPort;
}

class DirectoryAnalysisProgress {
  const DirectoryAnalysisProgress(this.totalItems, this.totalBytes);
  final int totalItems;
  final int totalBytes;
}

Future<DirectoryAnalysisResult> _analyzeDirectoryInIsolate(
  _AnalysisParams params,
) async {
  final dir = Directory(params.path);
  if (!dir.existsSync()) {
    return const DirectoryAnalysisResult(
      path: '',
      totalItems: 0,
      totalBytes: 0,
      diskUsage: null,
      categoryStats: {},
      allFiles: [],
    );
  }

  var totalItems = 0;
  var totalBytes = 0;
  final stats = <FileItemType, CategoryStats>{
    FileItemType.image: const CategoryStats(),
    FileItemType.video: const CategoryStats(),
    FileItemType.audio: const CategoryStats(),
    FileItemType.document: const CategoryStats(),
    FileItemType.archive: const CategoryStats(),
    FileItemType.other: const CategoryStats(),
  };

  final allFiles = <FileStatWithInfo>[];

  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
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

          allFiles.add(
            FileStatWithInfo(
              path: entity.path,
              name: name,
              stat: FileStatData(size: size, modified: stat.modified),
              type: type,
            ),
          );

          if (totalItems % 1000 == 0) {
            params.sendPort.send(DirectoryAnalysisProgress(totalItems, totalBytes));
          }
        } catch (_) {}
      }
    }
  } catch (_) {}

  // allFiles.sort((a, b) => b.stat.size.compareTo(a.stat.size)); // Let UI sort if needed

  return DirectoryAnalysisResult(
    path: params.path,
    totalItems: totalItems,
    totalBytes: totalBytes,
    diskUsage: null, // Fetched outside isolate
    categoryStats: stats,
    allFiles: allFiles,
  );
}

class _IsolateMessage {
  _IsolateMessage(this.params, this.sendPort);
  final _AnalysisParams params;
  final SendPort sendPort;
}

Future<void> _isolateEntry(_IsolateMessage msg) async {
  final result = await _analyzeDirectoryInIsolate(msg.params);
  msg.sendPort.send(result);
}

final directoryAnalysisProgressProvider = StateProvider.autoDispose.family<DirectoryAnalysisProgress?, String>((ref, path) {
  return null;
});

final directoryAnalysisStateProvider = StateProvider.autoDispose.family<AsyncValue<DirectoryAnalysisResult>?, String>((ref, path) {
  return null;
});

final directoryAnalysisProvider = FutureProvider.autoDispose.family<DirectoryAnalysisResult, String>((ref, path) async {
  final cached = ref.watch(directoryAnalysisStateProvider(path));
  if (cached != null) {
    if (cached.hasError) throw cached.error!;
    return cached.value!;
  }

  // 1. Get disk usage in main thread
  final diskUsage = await getDiskUsage(path);

  // 2. Spawn isolate for recursive traversal
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(
    _isolateEntry,
    _IsolateMessage(_AnalysisParams(path, receivePort.sendPort), receivePort.sendPort),
  );

  ref.onDispose(() {
    isolate.kill(priority: Isolate.immediate);
    receivePort.close();
  });

  DirectoryAnalysisResult? result;
  await for (final message in receivePort) {
    if (message is DirectoryAnalysisProgress) {
      ref.read(directoryAnalysisProgressProvider(path).notifier).state = message;
    } else if (message is DirectoryAnalysisResult) {
      result = message;
      break;
    }
  }
  
  isolate.kill();

  if (result == null) {
    throw Exception('Analysis failed to return a result.');
  }

  return DirectoryAnalysisResult(
    path: result.path,
    totalItems: result.totalItems,
    totalBytes: result.totalBytes,
    diskUsage: diskUsage,
    categoryStats: result.categoryStats,
    allFiles: result.allFiles,
  );
});

void removeFilesFromAnalysis(WidgetRef ref, String path, List<String> pathsToRemove) {
  final currentAsync = ref.read(directoryAnalysisProvider(path));
  if (!currentAsync.hasValue) return;
  final currentResult = currentAsync.value!;

  final pathsSet = pathsToRemove.toSet();
  final newAllFiles = currentResult.allFiles.where((f) => !pathsSet.contains(f.path)).toList();

  // Recompute stats
  var totalItems = 0;
  var totalBytes = 0;
  final stats = <FileItemType, CategoryStats>{
    FileItemType.image: const CategoryStats(),
    FileItemType.video: const CategoryStats(),
    FileItemType.audio: const CategoryStats(),
    FileItemType.document: const CategoryStats(),
    FileItemType.archive: const CategoryStats(),
    FileItemType.other: const CategoryStats(),
  };

  for (final file in newAllFiles) {
    totalItems++;
    totalBytes += file.stat.size;
    final type = file.type;
    final currentStat = stats[type]!;
    stats[type] = currentStat.copyWith(
      count: currentStat.count + 1,
      totalBytes: currentStat.totalBytes + file.stat.size,
    );
  }

  final newResult = DirectoryAnalysisResult(
    path: currentResult.path,
    totalItems: totalItems,
    totalBytes: totalBytes,
    diskUsage: currentResult.diskUsage,
    categoryStats: stats,
    allFiles: newAllFiles,
  );

  ref.read(directoryAnalysisStateProvider(path).notifier).state = AsyncData(newResult);
}
