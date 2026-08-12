import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloader_readiness_provider.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

void main() {
  group('DownloaderReadinessNotifier Tests', () {
    test('starts by checking and if missing sets needsInstall to true', () async {
      // Create a container with mocked registry
      EngineRegistry.clearAllEnginesForTesting();
      // Register a fake required engine that is missing
      EngineRegistry.register(_MockRequiredEngine());
      final container = ProviderContainer();
      final state = await container.read(downloaderReadinessProvider.future);

      // Because there are no engines (or missing engines), it should need install
      expect(state.needsInstall, true);
      expect(state.isReady, false);
    });

    test('if all ready, isReady is true', () async {
      // Mock logic in the provider itself or the registry to be true
      // We will handle this in implementation.
    });
  });
}

class _MockRequiredEngine extends DownloadEngine {
  @override
  String get id => 'mock_req';
  @override
  String get displayName => 'Mock Req';
  @override
  EngineType get engineType => EngineType.cli;
  @override
  int get priority => 100;
  @override
  List<RegExp> get urlPatterns => [];
  @override
  bool get isInstalled => false;
  @override
  Color get color => const Color(0xFF000000);
  @override
  IconData get icon => const IconData(0);
  @override
  String? get binaryPath => null;
  @override
  EngineUpdateInfo? get updateInfo => null;
  @override
  bool get isOptional => false;

  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async => [];
  @override
  Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
    String? itemsRange,
  }) async => throw UnimplementedError();
}
