import 'dart:io';
import 'package:flutter/foundation.dart';

class ProcessUtils {
  static void killProcessTree(int pid) {
    if (Platform.isLinux || Platform.isMacOS) {
      try {
        final result = Process.runSync('pgrep', ['-P', pid.toString()]);
        if (result.exitCode == 0) {
          final children = result.stdout.toString().split('\n').where((s) => s.trim().isNotEmpty);
          for (final child in children) {
            killProcessTree(int.parse(child));
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
