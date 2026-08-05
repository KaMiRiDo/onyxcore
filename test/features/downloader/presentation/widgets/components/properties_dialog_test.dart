import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/properties_dialog.dart';

void main() {
  testWidgets(
    'PropertiesDialog renders single item with smooth scrollable extraction logs',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var closed = false;

      final item = MediaInfo(
        id: '1',
        title: 'Sample Media',
        originalUrl: 'https://example.com/video',
        fetchLogs: 'Log line 1\nLog line 2\nLog line 3\nLog line 4\nLog line 5\nLog line 6\nLog line 7\nLog line 8\nLog line 9\nLog line 10',
      );
      final group = MediaGroup(items: [item], originalUrl: 'https://example.com/video');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [group],
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('Sample Media'), findsOneWidget);
      expect(find.text('Extraction Logs'), findsOneWidget);

      // Verify download and footer close buttons are removed
      expect(find.text('Download'), findsNothing);
      expect(find.text('Download All'), findsNothing);

      // Expand Extraction Logs if not already expanded
      await tester.tap(find.text('Extraction Logs'));
      await tester.pumpAndSettle();

      // Verify Scrollbar and SelectableText with smooth scrolling physics
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.textContaining('Log line 1'), findsOneWidget);

      // Verify smooth scrolling
      final scrollViewFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.physics is BouncingScrollPhysics,
      );
      expect(scrollViewFinder, findsOneWidget);

      // Test top-right close button
      final closeIconFinder = find.byIcon(Icons.close);
      expect(closeIconFinder, findsOneWidget);
      await tester.tap(closeIconFinder);
      expect(closed, isTrue);
    },
  );

  testWidgets(
    'PropertiesDialog initially expands logs when media item is in error state',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = MediaInfo(
        id: 'err1',
        title: 'Failed Item',
        originalUrl: 'https://example.com/error',
        isError: true,
        errorMessage: 'Extraction failed: Playwright not found',
        fetchLogs: 'Error Trace: Timeout waiting for selector\nFailed to extract',
      );
      final group = MediaGroup(items: [item], originalUrl: 'https://example.com/error');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [group],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify logs are visible immediately (initiallyExpanded = true)
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.textContaining('Error Trace: Timeout'), findsOneWidget);
    },
  );

  testWidgets(
    'PropertiesDialog calculates and displays size matching selected format and audio stream',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const videoFormat = MediaFormat(
        formatId: '137',
        extension: 'mp4',
        resolution: '1920x1012',
        formatString: '137 - 1920x1012 (1080p)',
        videoCodec: 'avc1.640028',
        audioCodec: 'none',
        filesize: 72876032, // ~69.5 MB
      );
      const audioFormat = MediaFormat(
        formatId: '140',
        extension: 'm4a',
        resolution: 'audio only',
        formatString: '140 - audio only (medium)',
        videoCodec: 'none',
        audioCodec: 'mp4a.40.2',
        filesize: 16693248, // ~15.9 MB
      );

      final item = MediaInfo(
        id: 'kalyani',
        title: 'KALYANI (with Shreya Ghoshal)',
        originalUrl: 'https://www.youtube.com/watch?v=kalyani',
        filesize: 229337583, // 218.71 MB raw metadata size
        formats: const [videoFormat, audioFormat],
      );
      final group = MediaGroup(
        items: [item],
        originalUrl: 'https://www.youtube.com/watch?v=kalyani',
      );

      // Total expected: 72876032 + 16693248 = 89569280 bytes = 85.42 MB
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [group],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('85.42 MB'), findsOneWidget);
      expect(find.textContaining('218.71 MB'), findsNothing);
    },
  );

  testWidgets(
    'PropertiesDialog uses provided getFormatBytes callback and config overrides',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const videoFormat720 = MediaFormat(
        formatId: '22',
        extension: 'mp4',
        resolution: '1280x720',
        formatString: '22 - 1280x720 (720p)',
        filesize: 41943040, // 40.0 MB
      );

      final item = MediaInfo(
        id: 'vid1',
        title: 'Custom Video',
        originalUrl: 'https://www.youtube.com/watch?v=custom',
        filesize: 104857600, // 100 MB
        formats: const [videoFormat720],
      );
      final group = MediaGroup(
        items: [item],
        originalUrl: 'https://www.youtube.com/watch?v=custom',
      );

      final config = DownloadConfig(
        itemFormats: {'vid1': videoFormat720},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [group],
              config: config,
              getFormatBytes: (info, fmt, cfg) => 41943040,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('40.00 MB'), findsOneWidget);
    },
  );
}
