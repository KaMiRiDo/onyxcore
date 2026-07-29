import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/process_utils.dart';

void main() {
  group('ProcessUtils', () {
    test('killProcessTree terminates a running process and its children', () async {
      // Spawn a process that spawns a child
      final process = await Process.start('sh', ['-c', 'sleep 100']);
      final pid = process.pid;

      // Verify it's running
      var exitCodeReceived = false;
      unawaited(process.exitCode.then((_) {
        exitCodeReceived = true;
      }));

      await ProcessUtils.killProcessTree(pid);

      // Wait a bit to ensure it is dead
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(exitCodeReceived, isTrue);
    });

    test('killProcessTreeSync terminates a running process and its children synchronously', () async {
      final process = await Process.start('sh', ['-c', 'sleep 100']);
      final pid = process.pid;

      var exitCodeReceived = false;
      unawaited(process.exitCode.then((_) {
        exitCodeReceived = true;
      }));

      ProcessUtils.killProcessTreeSync(pid);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(exitCodeReceived, isTrue);
    });

    test('killProcessTree handles invalid/already dead PID gracefully', () async {
      // 999999 is typically a non-existent PID on most machines
      await expectLater(
        ProcessUtils.killProcessTree(999999),
        completes,
      );
    });

    test('killProcessTreeSync handles invalid/already dead PID gracefully', () {
      expect(
        () => ProcessUtils.killProcessTreeSync(999999),
        returnsNormally,
      );
    });
  });
}
