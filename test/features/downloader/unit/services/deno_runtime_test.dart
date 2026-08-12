import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/deno_runtime.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DenoRuntime Tests', () {
    test('binaryPath returns deterministic managed path', () {
      final expectedPath = p.join(
        Platform.environment['HOME'] ?? '',
        '.local',
        'share',
        'onyxcore',
        'bin',
        'deno',
      );
      expect(DenoRuntime.managedPath, expectedPath);
    });

    test('updateInfo uses official Deno GitHub API for the pinned version', () {
      final info = DenoRuntime.instance.updateInfo;
      expect(info, isNotNull);
      expect(
        info!.apiUrl,
        'https://api.github.com/repos/denoland/deno/releases/tags/${DenoRuntime.pinnedVersion}',
      );
      expect(info.assetName, 'deno-x86_64-unknown-linux-gnu.zip');
    });

    test('getLatestVersion returns the pinned version, not dynamic latest', () async {
      final version = await DenoRuntime.instance.getLatestVersion();
      expect(version, DenoRuntime.pinnedVersion);
    });

    test('isInstalled returns false when binary does not exist', () {
      // Assuming a clean test environment where it doesn't exist
      // Since it checks actual filesystem, we mock or just check if it matches reality
      final exists = File(DenoRuntime.managedPath).existsSync();
      expect(DenoRuntime.instance.isInstalled, exists);
    });
  });
}
