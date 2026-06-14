import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

class _MockEngine extends DownloadEngine {
  @override
  String get id => 'mock_engine';

  @override
  String get displayName => 'Mock Engine';

  @override
  IconData get icon => Icons.download;

  @override
  Color get color => Colors.blue;

  @override
  EngineType get engineType => EngineType.cli;

  @override
  String? get binaryPath => null;

  @override
  List<RegExp> get urlPatterns => [];

  @override
  int get priority => 0;

  @override
  bool get isInstalled => true;

  @override
  EngineUpdateInfo? get updateInfo => null;

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
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('DownloadEngine Base Class Unit Tests', () {
    group('EngineType Enum', () {
      test('U-DL-ENG-01: Contain exactly 4 values', () {
        expect(EngineType.values.length, 4);
        expect(EngineType.values[0], EngineType.cli);
        expect(EngineType.values[1], EngineType.python);
        expect(EngineType.values[2], EngineType.script);
        expect(EngineType.values[3], EngineType.api);
      });

      test('U-DL-ENG-02: Resolve by name', () {
        expect(EngineType.cli.index, 0);
        expect(EngineType.values.byName('cli'), EngineType.cli);
      });
    });

    group('EngineUpdateInfo', () {
      test('U-DL-ENG-03: Create with all required fields', () {
        final info = EngineUpdateInfo(apiUrl: 'http://api', assetName: 'asset.zip');
        expect(info.apiUrl, 'http://api');
        expect(info.assetName, 'asset.zip');
        expect(info.checksumAssetName, isNull);
      });

      test('U-DL-ENG-04: Create with optional checksum', () {
        final info = EngineUpdateInfo(apiUrl: 'http://api', assetName: 'asset.zip', checksumAssetName: 'asset.zip.sha256');
        expect(info.checksumAssetName, 'asset.zip.sha256');
      });
    });

    group('PartialMetadataException', () {
      test('U-DL-ENG-05: Store partial infos and message', () {
        final partials = [
          MediaInfo(id: '1', title: '1', originalUrl: '1'),
          MediaInfo(id: '2', title: '2', originalUrl: '2'),
          MediaInfo(id: '3', title: '3', originalUrl: '3'),
        ];
        final exception = PartialMetadataException(partialInfos: partials, message: 'Timeout');
        expect(exception.partialInfos.length, 3);
        expect(exception.message, 'Timeout');
      });

      test('U-DL-ENG-06: Return message string', () {
        final exception = PartialMetadataException(partialInfos: const [], message: 'Timed out after 10 minutes');
        expect(exception.toString(), 'Timed out after 10 minutes');
      });

      test('U-DL-ENG-07: Implement Exception interface', () {
        final exception = PartialMetadataException(partialInfos: const [], message: 'Error');
        expect(exception, isA<Exception>());
      });

      test('U-DL-ENG-08: Handle empty partialInfos', () {
        final exception = PartialMetadataException(partialInfos: const [], message: 'No data');
        expect(exception.partialInfos, isEmpty);
        expect(exception.message, 'No data');
      });
    });

    group('DownloadEngine Default Implementations', () {
      late _MockEngine engine;

      setUp(() {
        engine = _MockEngine();
      });

      test('U-DL-ENG-09: Return empty list by default', () {
        expect(engine.systemDependencies, isEmpty);
      });

      test('U-DL-ENG-10: Return false by default', () {
        expect(engine.isOptional, isFalse);
      });

      test('U-DL-ENG-11: Return null by default for install', () async {
        expect(await engine.install(), isNull);
      });

      test('U-DL-ENG-12: Return null by default for uninstall', () async {
        expect(await engine.uninstall(), isNull);
      });

      test('U-DL-ENG-13: Return null by default for getInstalledVersion', () async {
        expect(await engine.getInstalledVersion(), isNull);
      });

      test('U-DL-ENG-14: Return null by default for getLatestVersion', () async {
        expect(await engine.getLatestVersion(), isNull);
      });
    });
  });
}
