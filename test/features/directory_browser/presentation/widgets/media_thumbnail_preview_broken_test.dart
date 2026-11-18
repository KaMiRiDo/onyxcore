import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/media_thumbnail_preview.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}
class MockThumbnailSession extends Mock implements ThumbnailSession {}

class FakeThumbnailSessionManager extends ThumbnailSessionManager {
  FakeThumbnailSessionManager(this._session);
  final ThumbnailSession? _session;

  @override
  ThumbnailSession? build() => _session;
}

void main() {
  late MockThumbnailCacheService mockCache;
  late MockThumbnailSession mockSession;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(
      const ThumbnailCandidate(
        path: '',
        type: FileItemType.image,
        modifiedEpochMs: 0,
        sizeBytes: 0,
      ),
    );
  });

  setUp(() async {
    mockCache = MockThumbnailCacheService();
    mockSession = MockThumbnailSession();
    tempDir = await Directory.systemTemp.createTemp('thumb_broken_test_');

    when(mockCache.ensureLoaded).thenAnswer((_) async {});
    when(
      () => mockCache.lookup(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
      ),
    ).thenReturn(ThumbnailLookupResult.miss);
    when(
      () => mockCache.lookupAsync(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
      ),
    ).thenAnswer((_) async => ThumbnailLookupResult.miss);
    when(() => mockSession.isCancelled).thenReturn(false);
    when(() => mockSession.isDisposed).thenReturn(false);
    when(
      () => mockSession.enqueueCandidate(any()),
    ).thenAnswer((_) async => ThumbnailJobOutcome.cancelled);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildWidget(FileItem item) {
    return ProviderScope(
      overrides: [
        thumbnailCacheServiceProvider.overrideWithValue(mockCache),
        activeThumbnailSessionProvider.overrideWith(
          () => FakeThumbnailSessionManager(mockSession),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 120,
            child: MediaThumbnailPreview(item: item, zoom: 1),
          ),
        ),
      ),
    );
  }

  testWidgets('renders broken image placeholder immediately when item.isBroken is true', (tester) async {
    final item = FileItem(
      path: '${tempDir.path}/broken.jpg',
      name: 'broken.jpg',
      type: FileItemType.image,
      modified: DateTime.now(),
      isBroken: true,
    );

    await tester.pumpWidget(buildWidget(item));
    await tester.pump();

    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);

    final svgWidget = tester.widget<SvgPicture>(svgFinder);
    final bytesLoader = svgWidget.bytesLoader as SvgAssetLoader;
    expect(bytesLoader.assetName, equals('assets/icons/broken_img_v2.svg'));
  });

  testWidgets('renders broken video placeholder immediately when video item.isBroken is true', (tester) async {
    final item = FileItem(
      path: '${tempDir.path}/broken.mp4',
      name: 'broken.mp4',
      type: FileItemType.video,
      modified: DateTime.now(),
      isBroken: true,
    );

    await tester.pumpWidget(buildWidget(item));
    await tester.pump();

    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);

    final svgWidget = tester.widget<SvgPicture>(svgFinder);
    final bytesLoader = svgWidget.bytesLoader as SvgAssetLoader;
    expect(bytesLoader.assetName, equals('assets/icons/broken_vid_v2.svg'));
  });

  testWidgets('detects 0-byte image file and renders broken image placeholder', (tester) async {
    final file = File('${tempDir.path}/empty.jpg')..createSync();
    when(
      () => mockCache.lookup(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
      ),
    ).thenReturn(ThumbnailLookupResult.miss);

    when(
      () => mockCache.lookupAsync(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
      ),
    ).thenAnswer((_) async => ThumbnailLookupResult.miss);

    final item = FileItem(
      path: file.path,
      name: 'empty.jpg',
      type: FileItemType.image,
      sizeBytes: 0,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildWidget(item));
    await tester.pumpAndSettle();

    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);

    final svgWidget = tester.widget<SvgPicture>(svgFinder);
    final bytesLoader = svgWidget.bytesLoader as SvgAssetLoader;
    expect(bytesLoader.assetName, equals('assets/icons/broken_img_v2.svg'));
  });
}
