import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service to handle archive operations wrapping the system's `7z` binary.
class ArchiveService {
  static final List<Process> _activeProcesses = [];

  /// Checks if an archive requires a password for extraction.
  static Future<bool> isEncrypted(String archivePath) async {
    try {
      // '7z l -slt <archive>' lists technical details, where Encrypted = + indicates password protection.
      final result = await Process.run('7z', ['l', '-slt', archivePath]);
      return result.stdout.toString().contains('Encrypted = +');
    } catch (e) {
      debugPrint('Error checking encryption (is 7z installed?): $e');
      return false; // Fallback
    }
  }

  /// Extracts an archive to the specified output directory.
  static Future<void> extract({
    required String archivePath,
    required String outputDir,
    String? password,
    void Function(double)? onProgress,
    void Function(String)? onLog,
  }) async {
    final args = ['x', archivePath, '-o$outputDir', '-y', '-bsp1'];
    if (password != null && password.isNotEmpty) {
      args.add('-p$password');
    }

    await _runProcess('7z', args, onProgress, onLog);
  }

  /// Compresses a list of source paths into a target archive.
  static Future<void> compress({
    required List<String> sourcePaths,
    required String targetArchive,
    String? password,
    void Function(double)? onProgress,
    void Function(String)? onLog,
  }) async {
    final args = ['a', targetArchive, ...sourcePaths, '-y', '-bsp1'];
    if (password != null && password.isNotEmpty) {
      args.add('-p$password');
      if (targetArchive.toLowerCase().endsWith('.7z')) {
        args.add(
          '-mhe=on',
        ); // Encrypt headers as well (only supported by 7z format)
      }
    }

    await _runProcess('7z', args, onProgress, onLog);
  }

  static Future<void> _runProcess(
    String executable,
    List<String> args,
    void Function(double)? onProgress,
    void Function(String)? onLog,
  ) async {
    Process? process;
    try {
      process = await Process.start(executable, args);
      _activeProcesses.add(process);

      final stdoutFuture = process.stdout.transform(utf8.decoder).forEach((data) {
        // 7z -bsp1 output looks like: " 23% 4 - file.txt" or " 12%"
        if (onProgress != null) {
          final regex = RegExp(r'(\d+)%');
          for (final line in data.split('\n')) {
            final match = regex.firstMatch(line);
            if (match != null) {
              final percentStr = match.group(1);
              if (percentStr != null) {
                final percent = double.tryParse(percentStr);
                if (percent != null) {
                  onProgress(percent / 100.0);
                }
              }
            }
          }
        }
        if (onLog != null) {
          onLog(data.trim());
        }
      });

      final stderrFuture = process.stderr.transform(utf8.decoder).forEach((data) {
        if (onLog != null) {
          onLog('ERROR: ${data.trim()}');
        }
      });

      final exitCode = await process.exitCode;
      await Future.wait([stdoutFuture, stderrFuture]);
      
      if (exitCode != 0) {
        throw Exception(
          'Archive operation failed with code $exitCode (Check password or 7z availability).',
        );
      }
    } finally {
      if (process != null) {
        _activeProcesses.remove(process);
      }
    }
  }

  /// Terminates all currently active 7z child processes.
  /// Used during application teardown to prevent zombie processes.
  static void killZombies() {
    for (final process in _activeProcesses) {
      process.kill();
    }
    _activeProcesses.clear();
    debugPrint('[ArchiveService] Zombie 7z processes killed.');
  }
}
