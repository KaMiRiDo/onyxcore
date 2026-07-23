import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_preview.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

void main() {
  late MockThumbnailCacheService mockCacheService;

  setUp(() {
    mockCacheService = MockThumbnailCacheService();
    when(() => mockCacheService.ensureLoaded()).thenAnswer((_) async {});
    when(() => mockCacheService.lookupAsync(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        )).thenAnswer((_) async => ThumbnailLookupResult.failed);
  });

  testWidgets('ItemPreview renders file icon for generic file', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
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
            body: ItemPreview(
              item: item,
              zoom: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview renders folder icon for directory', (tester) async {
    final item = FileItem(
      path: '/home/user/Documents',
      name: 'Documents',
      type: FileItemType.folder,
      sizeBytes: 0,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemPreview(
              item: item,
              zoom: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.article_rounded), findsOneWidget);
  });

  testWidgets('ItemPreview renders image icon for image file if error in loading', (tester) async {
    final item = FileItem(
      path: '/home/user/image.png',
      name: 'image.png',
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
            body: ItemPreview(
              item: item,
              zoom: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ItemPreview), findsOneWidget);
  });
}
