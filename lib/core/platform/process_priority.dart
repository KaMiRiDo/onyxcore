import 'dart:io';

/// Best-effort process priority adjustment for background thumbnail generation.
///
/// On Linux, uses `renice` to lower the CPU scheduling priority of the process.
/// On unsupported platforms or upon failure, silently returns `false` without
/// affecting thumbnail generation.
Future<bool> setLowProcessPriority(int pid, [int niceLevel = 10]) async {
  if (!Platform.isLinux) return false;
  try {
    final result = await Process.run('renice', ['-n', '$niceLevel', '-p', '$pid']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
