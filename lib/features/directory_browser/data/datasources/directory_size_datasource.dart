import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final directorySizeDatasourceProvider = Provider<DirectorySizeDatasource>((ref) {
  return DirectorySizeDatasource();
});

class DirectorySizeDatasource {
  Future<Map<String, int>> getDirectorySizes(List<String> paths) async {
    return Isolate.run(() {
      final result = <String, int>{};
      
      if (Platform.isLinux || Platform.isMacOS) {
        const chunkSize = 500;
        for (var i = 0; i < paths.length; i += chunkSize) {
          final chunk = paths.skip(i).take(chunkSize).toList();
          try {
            final res = Process.runSync('du', ['-sb', ...chunk]);
            if (res.exitCode == 0) {
              final lines = res.stdout.toString().trim().split('\n');
              for (final line in lines) {
                if (line.isEmpty) continue;
                final parts = line.split(RegExp(r'\s+'));
                if (parts.length >= 2) {
                  final size = int.tryParse(parts[0]);
                  final path = parts.sublist(1).join(' ').trim();
                  if (size != null) {
                    result[path] = size;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      for (final path in paths) {
        if (!result.containsKey(path)) {
          final size = _getDirectorySizeSync(path);
          if (size != null) {
            result[path] = size;
          }
        }
      }
      return result;
    });
  }

  Future<int?> getDirectorySize(String path) async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      return Isolate.run(() => _getDirectorySizeSync(path));
    }
    
    try {
      final result = await Process.run('du', ['-sb', path]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final sizeStr = output.split(RegExp(r'\s+')).first;
          return int.tryParse(sizeStr);
        }
      }
    } catch (_) {}
    
    return Isolate.run(() => _getDirectorySizeSync(path));
  }

  static int? _getDirectorySizeSync(String path) {
    try {
      var totalSize = 0;
      final dir = Directory(path);
      if (!dir.existsSync()) return null;
      
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          totalSize += entity.lengthSync();
        }
      }
      return totalSize;
    } catch (_) {
      return null;
    }
  }
}
