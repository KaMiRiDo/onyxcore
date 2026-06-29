import 'dart:io';
import 'package:flutter/foundation.dart';

class ProcessUtils {
  /// Gracefully kills a process tree with SIGTERM first, then SIGKILL after a grace period.
  /// This allows yt-dlp/gallery-dl to clean up temp files and partial downloads.
  static Future<void> killProcessTree(int pid) async {
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        // Kill children first (bottom-up traversal)
        final result = Process.runSync('pgrep', ['-P', pid.toString()]);
        if (result.exitCode == 0) {
          final children = result.stdout
              .toString()
              .split('\n')
              .where((s) => s.trim().isNotEmpty);
          for (final child in children) {
            await killProcessTree(int.parse(child));
          }
        }
        // Phase 1: Graceful termination
        try {
          Process.killPid(pid, ProcessSignal.sigterm);
        } catch (_) {
          return; // Process already dead
        }
        // Wait up to 1 second for graceful exit
        await Future<void>.delayed(const Duration(seconds: 1));
        // Phase 2: Force kill if still alive
        try {
          Process.killPid(pid, ProcessSignal.sigkill);
        } catch (_) {
          // Process already terminated gracefully
        }
      } on Exception catch (e) {
        debugPrint('Error killing $pid: $e');
      }
    } else {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }

  /// Synchronous kill for use in window close handlers where async is not possible.
  /// Falls back to immediate SIGKILL since we can't await in dispose/close handlers.
  static void killProcessTreeSync(int pid) {
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        final result = Process.runSync('pgrep', ['-P', pid.toString()]);
        if (result.exitCode == 0) {
          final children = result.stdout
              .toString()
              .split('\n')
              .where((s) => s.trim().isNotEmpty);
          for (final child in children) {
            killProcessTreeSync(int.parse(child));
          }
        }
        Process.killPid(pid, ProcessSignal.sigkill);
      } on Exception catch (e) {
        debugPrint('Error killing $pid: $e');
      }
    } else {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
  }
}
