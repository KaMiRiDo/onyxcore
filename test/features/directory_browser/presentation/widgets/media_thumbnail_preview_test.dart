import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class FakeThumbnailSessionManager extends ThumbnailSessionManager {
  FakeThumbnailSessionManager(this._session);
  final ThumbnailSession? _session;

  @override
  ThumbnailSession? build() => _session;
}

void main() {
  late Directory tempDir;
  late ThumbnailSession testSession;

  setUpAll(() {
    registerFallbackValue(ThumbnailSize.normal);
    registerFallbackValue(File(''));
    tempDir = Directory('./test_temp_thumbnails')..createSync(recursive: true);
  });

  setUp(() {
    testSession = ThumbnailSession(
      folderPath: '/path/to',
      tabId: 'test_tab',
    );
  });

  tearDown(() {
    testSession.dispose();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('MediaThumbnailPreview handles unplayable video gracefully', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    when(() => mockCacheService.lookupAsync(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.failed);
    when(() => mockCacheService.markFailed(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) async {});

    final item = FileItem(
      path: '/path/to/nonexistent/video.mp4',
      name: 'video.mp4',
      type: FileItemType.video,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
          activeThumbnailSessionProvider.overrideWith(() => FakeThumbnailSessionManager(testSession)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaThumbnailPreview(
              item: item,
              zoom: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MediaThumbnailPreview), findsOneWidget);
  });

  testWidgets('MediaThumbnailPreview loads cached thumbnail for video', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    when(() => mockCacheService.lookupAsync(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.hit);
    
    final tempVideoThumb = File('${tempDir.path}/cached_video_test.jpg')..createSync();
    addTearDown(tempVideoThumb.deleteSync);

    when(() => mockCacheService.getCachedPathAsync(any())).thenAnswer((_) async => tempVideoThumb.path);

    final item = FileItem(
      path: '/path/to/video.mp4',
      name: 'video.mp4',
      type: FileItemType.video,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
            activeThumbnailSessionProvider.overrideWith(() => FakeThumbnailSessionManager(testSession)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaThumbnailPreview(
                item: item,
                zoom: 1,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('MediaThumbnailPreview loads cached thumbnail for image', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    when(() => mockCacheService.lookupAsync(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.hit);
        
    final tempImageThumb = File('${tempDir.path}/cached_image_test.jpg')..createSync();
    addTearDown(tempImageThumb.deleteSync);

    when(() => mockCacheService.getCachedPathAsync(any())).thenAnswer((_) async => tempImageThumb.path);

    final item = FileItem(
      path: '/path/to/image.jpg',
      name: 'image.jpg',
      type: FileItemType.image,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
            activeThumbnailSessionProvider.overrideWith(() => FakeThumbnailSessionManager(testSession)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaThumbnailPreview(
                item: item,
                zoom: 1,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ClipRRect), findsWidgets);
  });

  testWidgets('MediaThumbnailPreview runs fallback thumbnail generation and didUpdateWidget', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    
    // For item1, return miss to trigger enqueueing
    when(() => mockCacheService.lookupAsync(
          filePath: '/path/to/test_image.xyz',
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.miss);

    // For item2, return hit to avoid triggering a second enqueueing that would clog the queue
    when(() => mockCacheService.lookupAsync(
          filePath: '/path/to/another_image.xyz',
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.hit);

    final tempImageThumb = File('${tempDir.path}/cached_another_test.jpg')..createSync();
    addTearDown(tempImageThumb.deleteSync);
    when(() => mockCacheService.getCachedPathAsync('/path/to/another_image.xyz')).thenAnswer((_) async => tempImageThumb.path);

    when(() => mockCacheService.markFailed(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) async {});
    when(() => mockCacheService.storeThumbnail(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
          kind: any(named: 'kind'),
          thumbnailFile: any(named: 'thumbnailFile'),
        )).thenAnswer((_) async {});

    final item1 = FileItem(
      path: '/path/to/test_image.xyz',
      name: 'test_image.xyz',
      type: FileItemType.image,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    final item2 = FileItem(
      path: '/path/to/another_image.xyz',
      name: 'another_image.xyz',
      type: FileItemType.image,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    var tapped = false;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
            activeThumbnailSessionProvider.overrideWith(() => FakeThumbnailSessionManager(testSession)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      MediaThumbnailPreview(
                        item: tapped ? item2 : item1,
                        zoom: 1,
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => tapped = true),
                        child: const Text('Change'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });

    await tester.pumpAndSettle();

    // Trigger didUpdateWidget
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
  });

  test('ThumbnailSession order and reprioritization via session', () async {
    final session = ThumbnailSession(
      folderPath: '/path/to',
      tabId: 'tab_test',
    );
    addTearDown(session.dispose);

    final order = <int>[];
    final gate = Completer<void>();

    final f1 = session.enqueue(ThumbnailJob(
      filePath: 'file1.mp4',
      size: ThumbnailSize.normal,
      priority: 10,
      task: () async {
        await gate.future;
        order.add(1);
      },
    ));

    final f2 = session.enqueue(ThumbnailJob(
      filePath: 'file2.mp4',
      size: ThumbnailSize.normal,
      priority: 20,
      task: () async {
        order.add(2);
      },
    ));

    final f3 = session.enqueue(ThumbnailJob(
      filePath: 'file3.mp4',
      size: ThumbnailSize.normal,
      priority: 30,
      task: () async {
        order.add(3);
      },
    ));

    // Reprioritize file3 so it runs before file2 (gets priority 0)
    session.reprioritize({'file3.mp4'});

    gate.complete();
    await Future.wait([f1, f2, f3]);

    expect(order.first, 1);
    expect(order, containsAllInOrder([1, 3, 2]));
  });

  testWidgets('MediaThumbnailPreview gracefully handles corrupted or missing cached image without crashing', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    when(() => mockCacheService.lookupAsync(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.hit);
    when(() => mockCacheService.getCachedPathAsync(any(), size: any(named: 'size')))
        .thenAnswer((_) async => '/tmp/nonexistent_image_thumb.jpg');

    final item = FileItem(
      path: '/path/to/corrupt.jpg',
      name: 'corrupt.jpg',
      type: FileItemType.image,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
          activeThumbnailSessionProvider.overrideWith(() => FakeThumbnailSessionManager(testSession)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaThumbnailPreview(
              item: item,
              zoom: 1,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MediaThumbnailPreview), findsOneWidget);
  });
}
