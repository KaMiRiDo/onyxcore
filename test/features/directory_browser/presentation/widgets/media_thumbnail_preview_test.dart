import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/media_thumbnail_preview.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ThumbnailSize.normal);
  });

  testWidgets('MediaThumbnailPreview handles unplayable video gracefully', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    when(() => mockCacheService.lookup(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenReturn(ThumbnailLookupResult.failed);

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
    when(() => mockCacheService.lookup(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenReturn(ThumbnailLookupResult.hit);
    
    final tempVideoThumb = File('/tmp/cached_video_test.jpg')..createSync();
    addTearDown(tempVideoThumb.deleteSync);

    when(() => mockCacheService.getCachedPath(any(), size: any(named: 'size'))).thenReturn(tempVideoThumb.path);

    final item = FileItem(
      path: '/path/to/video.mp4',
      name: 'video.mp4',
      type: FileItemType.video,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
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

    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('MediaThumbnailPreview loads cached thumbnail for image', (tester) async {
    final mockCacheService = MockThumbnailCacheService();
    when(mockCacheService.ensureLoaded).thenAnswer((_) async {});
    when(() => mockCacheService.lookup(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenReturn(ThumbnailLookupResult.hit);
        
    final tempImageThumb = File('/tmp/cached_image_test.jpg')..createSync();
    addTearDown(tempImageThumb.deleteSync);

    when(() => mockCacheService.getCachedPath(any(), size: any(named: 'size'))).thenReturn(tempImageThumb.path);

    final item = FileItem(
      path: '/path/to/image.jpg',
      name: 'image.jpg',
      type: FileItemType.image,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
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

    expect(find.byType(ClipRRect), findsWidgets);
  });
}
