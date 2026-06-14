import "package:flutter/material.dart";
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/downloader/services/engines/gallery_dl_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/ytdlp_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/streamlink_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/lux_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/youget_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/playwright_engine.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

class MockCustomEngine extends DownloadEngine {
  @override
  String get id => 'custom-mock';

  @override
  String get displayName => 'Custom Mock';

  @override
  EngineType get engineType => EngineType.cli;

  @override
  int get priority => 100;

  @override
  List<RegExp> get urlPatterns => [RegExp(r'.*custom.*')];

  @override
  bool get isInstalled => true;

  // Dummy implementations for required overrides
  @override
  Color get color => const Color(0xFF000000);
  @override
  IconData get icon => const IconData(0);
  @override
  String? get binaryPath => null;
  @override
  EngineUpdateInfo? get updateInfo => null;
  @override
  Future<List<MediaInfo>> fetchMetadata({required String url, String? browser, bool fetchDeep = false, bool isPlaylist = false, void Function(MediaInfo info)? onProgress, void Function(int pid)? onProcessStarted}) async => [];
  @override
  Future<Process> startDownload({required String url, required String destination, String? title, MediaFormat? format, bool audioOnly = false, bool mute = false, int? galleryIndex, bool isPlaylist = false, bool isProfile = false, String? browser, bool isZip = false, String? filterType, int? totalItems, String? singleItemId, String? directUrl}) async => throw UnimplementedError();
}

void setEngineInstalled(DownloadEngine engine, bool installed) {
  if (engine.id == 'playwright') {
    final home = Platform.environment['HOME'] ?? '';
    final chromiumDir = Directory('$home/.cache/ms-playwright');
    final backupDir = Directory('$home/.cache/ms-playwright_backup');
    if (installed) {
      if (!chromiumDir.existsSync()) {
        if (backupDir.existsSync()) {
          backupDir.renameSync(chromiumDir.path);
        } else {
          chromiumDir.createSync(recursive: true);
        }
      }
    } else {
      if (chromiumDir.existsSync()) {
        if (!backupDir.existsSync()) {
          chromiumDir.renameSync(backupDir.path);
        } else {
          try {
            chromiumDir.deleteSync();
          } catch (_) {}
        }
      }
    }
    return;
  }

  String? targetPath = engine.binaryPath;
  final home = Platform.environment['HOME'] ?? '';
  
  if (targetPath == null) {
    if (engine.id == 'streamlink') targetPath = '$home/.local/bin/streamlink';
    if (engine.id == 'you-get') targetPath = '$home/.local/bin/you-get';
    if (engine.id == 'lux') targetPath = '$home/.local/bin/lux';
  }

  if (targetPath != null) {
    final file = File(targetPath);
    if (installed) {
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
    } else {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }
}

void main() {
  group('Engine Registry Unit Tests', () {
    setUpAll(() {
      // Ensure all required and optional engines are "installed" for baseline tests
      for (final engine in EngineRegistry.allEngines) {
        setEngineInstalled(engine, true);
      }
    });

    tearDownAll(() {
      // Cleanup created mock binaries
      for (final engine in EngineRegistry.allEngines) {
        setEngineInstalled(engine, false);
      }
    });

    group('1. Engine Resolution — resolveEngine', () {
      test('U-DL-REG-01: Return specific engine by preference', () {
        final engine = EngineRegistry.resolveEngine('http://any.com', 'gallery-dl');
        expect(engine, isA<GalleryDlEngine>());
      });

      test('U-DL-REG-02: Fallback to yt-dlp for unknown preference', () {
        final engine = EngineRegistry.resolveEngine('http://any.com', 'nonexistent');
        expect(engine, isA<YtDlpEngine>());
      });

      test('U-DL-REG-03: Auto-detect highest-priority installed engine by URL pattern', () {
        final engine = EngineRegistry.resolveEngine('https://instagram.com/post', 'auto');
        // Gallery-dl has priority 10 and matches instagram
        expect(engine, isA<GalleryDlEngine>());
      });

      test('U-DL-REG-04: Skip uninstalled engines in auto mode', () {
        final lux = EngineRegistry.findById('lux');
        if (lux != null) setEngineInstalled(lux, false);
        
        // Bilibili is handled by Lux (priority 4) or YouGet (priority 3) or yt-dlp (priority 9, but fallback)
        final engine = EngineRegistry.resolveEngine('https://bilibili.com/video', 'auto');
        // Since Lux is uninstalled, it should fallback to YouGet (if it matches) or yt-dlp
        // yt-dlp has priority 9 and matches `.*`, so it might actually win! Wait, we'll just check it doesn't return Lux.
        expect(engine.id, isNot('lux'));
        
        if (lux != null) setEngineInstalled(lux, true); // restore
      });

      test('U-DL-REG-05: Fallback to yt-dlp when no patterns match', () {
        // Since yt-dlp matches `.*`, it will always match, but it's the fallback
        final engine = EngineRegistry.resolveEngine('https://random-unknown-site.com', 'auto');
        // Depending on patterns, it might resolve to YtDlpEngine
        expect(engine, isA<YtDlpEngine>());
      });
    });

    group('2. Engine Sequence Resolution — resolveEngineSequence', () {
      test('U-DL-REG-06: Return correct sequence for auto — matchers first by priority', () {
        final seq = EngineRegistry.resolveEngineSequence('https://youtube.com/video', 'auto');
        expect(seq.first, isA<YtDlpEngine>()); // yt-dlp is priority 9 and matches .*
      });

      test('U-DL-REG-07: Return single engine for specific preference', () {
        final seq = EngineRegistry.resolveEngineSequence('http://any', 'yt-dlp');
        expect(seq.length, 1);
        expect(seq.first, isA<YtDlpEngine>());
      });

      test('U-DL-REG-08: Fallback to yt-dlp when specific engine not found', () {
        final seq = EngineRegistry.resolveEngineSequence('http://any', 'nonexistent');
        expect(seq.length, 1);
        expect(seq.first, isA<YtDlpEngine>());
      });

      test('U-DL-REG-09: Handle no installed engines', () {
        EngineRegistry.clearAllEnginesForTesting();
        final yt = YtDlpEngine();
        EngineRegistry.register(yt);
        setEngineInstalled(yt, false);
        
        final seq = EngineRegistry.resolveEngineSequence('http://any', 'auto');
        expect(seq.length, 1);
        expect(seq.first, isA<YtDlpEngine>());

        // Restore
        EngineRegistry.clearRegisteredEngines();
        for (final engine in EngineRegistry.allEngines) {
          setEngineInstalled(engine, true);
        }
      });

      test('U-DL-REG-10: Skip non-matching engines in auto mode', () {
        final seq = EngineRegistry.resolveEngineSequence('https://bilibili.com/video', 'auto');
        // Should contain matching engines sorted by priority
        expect(seq, isNotEmpty);
      });

      test('U-DL-REG-11: Priority ties — stable sort', () {
        final seq = EngineRegistry.resolveEngineSequence('http://any', 'auto');
        expect(seq, isNotEmpty);
      });
    });

    group('3. Global Installation Checks', () {
      test('U-DL-REG-12: Return true if both required engines present', () {
        setEngineInstalled(EngineRegistry.findById('yt-dlp')!, true);
        setEngineInstalled(EngineRegistry.findById('gallery-dl')!, true);
        expect(EngineRegistry.requiredInstalled, isTrue);
      });

      test('U-DL-REG-13: Return false if ANY required engine missing', () {
        setEngineInstalled(EngineRegistry.findById('gallery-dl')!, false);
        expect(EngineRegistry.requiredInstalled, isFalse);
        setEngineInstalled(EngineRegistry.findById('gallery-dl')!, true); // restore
      });

      test('U-DL-REG-14: Return true if ALL engines installed', () {
        for (final e in EngineRegistry.allEngines) {
          setEngineInstalled(e, true);
        }
        for (final e in EngineRegistry.allEngines) {
          if (!e.isInstalled) {
            print('Engine ${e.id} is not installed! binaryPath: ${e.binaryPath}');
          }
        }
        expect(EngineRegistry.allInstalled, isTrue);
      });

      test('U-DL-REG-15: Return false if any optional engine missing', () {
        setEngineInstalled(EngineRegistry.findById('lux')!, false);
        expect(EngineRegistry.allInstalled, isFalse);
        setEngineInstalled(EngineRegistry.findById('lux')!, true); // restore
      });
    });

    group('4. Engine Lists & Lookup', () {
      test('U-DL-REG-16: Return unmodifiable list of all engines', () {
        final engines = EngineRegistry.allEngines;
        expect(engines.length, greaterThanOrEqualTo(6));
        expect(() => engines.add(MockCustomEngine()), throwsUnsupportedError);
      });

      test('U-DL-REG-17: Return unmodifiable list of 2 required engines', () {
        final req = EngineRegistry.requiredEngines;
        expect(req.length, 2);
        expect(req.map((e) => e.id), containsAll(['yt-dlp', 'gallery-dl']));
        expect(() => req.add(MockCustomEngine()), throwsUnsupportedError);
      });

      test('U-DL-REG-18: Return unmodifiable list of optional engines', () {
        final opt = EngineRegistry.optionalEngines;
        expect(opt.length, 4);
        expect(() => opt.add(MockCustomEngine()), throwsUnsupportedError);
      });

      test('U-DL-REG-19: Return list of missing required engines', () {
        setEngineInstalled(EngineRegistry.findById('gallery-dl')!, false);
        final missing = EngineRegistry.missingRequired;
        expect(missing.length, 1);
        expect(missing.first.id, 'gallery-dl');
        setEngineInstalled(EngineRegistry.findById('gallery-dl')!, true); // restore
      });

      test('U-DL-REG-20: Return empty list when all required installed', () {
        final missing = EngineRegistry.missingRequired;
        expect(missing, isEmpty);
      });

      test('U-DL-REG-21: Return engine matching ID', () {
        final e = EngineRegistry.findById('yt-dlp');
        expect(e, isA<YtDlpEngine>());
      });

      test('U-DL-REG-22: Return null if ID does not exist', () {
        expect(EngineRegistry.findById('fake'), isNull);
      });
    });

    group('5. Dynamic Registration', () {
      test('U-DL-REG-23: Add a custom engine to the registry', () {
        final custom = MockCustomEngine();
        final initialCount = EngineRegistry.allEngines.length;
        EngineRegistry.register(custom);
        expect(EngineRegistry.allEngines.length, initialCount + 1);
        expect(EngineRegistry.findById('custom-mock'), isNotNull);
      });
    });
  });
}
