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

  Widget buildTestWidget({required FileItem item, double zoom = 1.0}) {
    return ProviderScope(
      overrides: [
        thumbnailCacheServiceProvider.overrideWithValue(mockCacheService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: ItemPreview(item: item, zoom: zoom),
              ),
              ItemTitle(name: item.name, zoom: zoom),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('ItemPreview folder icon mapping', (tester) async {
    final item = FileItem(
      path: '/home/user/Downloads',
      name: 'Downloads',
      type: FileItemType.folder,
      sizeBytes: 0,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();

    // Icon returned by getFolderIconConfig('Downloads') is Icons.file_download_rounded
    expect(find.byIcon(Icons.file_download_rounded), findsOneWidget);
  });

  testWidgets('ItemPreview video icon mapping', (tester) async {
    final item = FileItem(
      path: '/home/user/video.mp4',
      name: 'video.mp4',
      type: FileItemType.video,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();

    // Video preview falls back to SvgPicture when thumbnail cache fails
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview README / Markdown svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/README.md',
      name: 'README.md',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview PDF svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/doc.pdf',
      name: 'doc.pdf',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview ZIP/RAR svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/archive.zip',
      name: 'archive.zip',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview Document svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/word.docx',
      name: 'word.docx',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview Spreadsheet svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/sheets.xlsx',
      name: 'sheets.xlsx',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview Presentation svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/slides.pptx',
      name: 'slides.pptx',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview Audio svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/song.mp3',
      name: 'song.mp3',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview Txt/Log svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/file.txt',
      name: 'file.txt',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview Executable svg fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/app.exe',
      name: 'app.exe',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview unknown type fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/unknown.xyz',
      name: 'unknown.xyz',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview executable flag fallback', (tester) async {
    final item = FileItem(
      path: '/home/user/unknown_exec',
      name: 'unknown_exec',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
      isExecutable: true,
    );

    await tester.pumpWidget(buildTestWidget(item: item));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemTitle renders correctly', (tester) async {
    final item = FileItem(
      path: '/home/user/test.txt',
      name: 'test.txt',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(item: item, zoom: 1.5));
    await tester.pumpAndSettle();
    expect(find.text('test.txt'), findsOneWidget);
  });
}
