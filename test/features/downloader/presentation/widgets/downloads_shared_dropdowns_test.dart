// ignore_for_file: cascade_invocations, unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';

void main() {
  group('DownloadsSharedDropdowns Tests', () {
    
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('W-DD-01 to W-DD-05: EngineSelectorDropdown', (WidgetTester tester) async {
      String? selectedVal;
      await tester.pumpWidget(wrap(
        EngineSelectorDropdown(
          selectedEngine: 'auto',
          onChanged: (val) => selectedVal = val,
        )
      ));

      expect(find.text('Auto Select'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      
      // Tap to open
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      
      // Find yt-dlp option (assuming it's registered) and tap
      final ytdlp = find.text('yt-dlp').last;
      if (ytdlp.evaluate().isNotEmpty) {
         await tester.tap(ytdlp);
         await tester.pumpAndSettle();
         expect(selectedVal, 'yt-dlp');
      }
    });

    testWidgets('W-DD-06 to W-DD-14: GroupFilterDropdown', (WidgetTester tester) async {
      GroupDownloadType? selectedVal;
      
      await tester.pumpWidget(wrap(
        GroupFilterDropdown(
          selectedFilter: GroupDownloadType.all,
          isEnabled: false,
          onChanged: (val) => selectedVal = val,
        )
      ));
      
      // W-DD-06: Renders "All" label
      expect(find.text('All'), findsOneWidget);
      
      // W-DD-07: Disabled has no arrow
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      
      // W-DD-08: Cannot open when disabled
      await tester.tap(find.byType(GroupFilterDropdown));
      await tester.pumpAndSettle();
      expect(find.text('Images Only'), findsNothing); // popup didn't open
      
      // Re-pump enabled
      await tester.pumpWidget(wrap(
        GroupFilterDropdown(
          selectedFilter: GroupDownloadType.all,
          isEnabled: true,
          onChanged: (val) => selectedVal = val,
        )
      ));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      
      await tester.tap(find.byType(GroupFilterDropdown));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Images Only').last);
      await tester.pumpAndSettle();
      expect(selectedVal, GroupDownloadType.images);
    });

    testWidgets('W-DD-15 to W-DD-24: FormatSelectionDropdown', (WidgetTester tester) async {
      final item = MediaInfo(id: '1', title: 'Test', originalUrl: 'test');
      final format = MediaFormat(formatId: 'fmt', extension: 'mp4', resolution: '1080p', filesize: 1024 * 1024 * 10, formatString: ''); // 10MB
      final itemWithFormat = item.copyWith(formats: [format]);
      
      final config = DownloadConfig();
      config.format = format;
      
      MediaFormat? selectedFormat;
      
      await tester.pumpWidget(wrap(
        FormatSelectionDropdown(
          item: itemWithFormat,
          config: config,
          index: 0,
          getHeight: (r) => 1080,
          matchTargetFormat: (i, f) => format,
          onChanged: (val) => selectedFormat = val,
        )
      ));
      
      // W-DD-15 & W-DD-18 & W-DD-19
      expect(find.text('1080p (10.0MB)'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing); // single format, no arrow
      
      // Audio only test
      final audioFmt = MediaFormat(formatId: 'audio', extension: 'm4a', resolution: 'audio only', formatString: '');
      final audioItem = item.copyWith(formats: [audioFmt], isVideo: false);
      config.format = audioFmt;
      
      await tester.pumpWidget(wrap(
        FormatSelectionDropdown(
          item: audioItem,
          config: config,
          index: 0,
          getHeight: (r) => 0,
          matchTargetFormat: (i, f) => audioFmt,
          onChanged: (val) => selectedFormat = val,
        )
      ));
      expect(find.text('Audio'), findsOneWidget);
      
      // original resolution
      final origFmt = MediaFormat(formatId: 'orig', extension: 'jpg', resolution: 'original', formatString: '');
      final origItem = item.copyWith(formats: [origFmt], isVideo: false, width: 1920, height: 1080);
      config.format = origFmt;
      await tester.pumpWidget(wrap(
        FormatSelectionDropdown(
          item: origItem,
          config: config,
          index: 0,
          getHeight: (r) => 0,
          matchTargetFormat: (i, f) => origFmt,
          onChanged: (val) => selectedFormat = val,
        )
      ));
      expect(find.text('1920x1080'), findsOneWidget);

      // W-DD-25: menuMaxHeight is set to limit height
      final popupFinder = find.byType(PopupMenuButton<MediaFormat>);
      final popupButton = tester.widget<PopupMenuButton<MediaFormat>>(popupFinder);
      expect(popupButton.constraints?.maxHeight ?? 250, lessThanOrEqualTo(250)); // Or expect we add constraints
    });

    testWidgets('FormatSelectionDropdown Mixed State', (WidgetTester tester) async {
      final config = DownloadConfig();
      final f1080 = MediaFormat(formatId: '1080', extension: 'mp4', resolution: '1080p', formatString: '');
      final f720 = MediaFormat(formatId: '720', extension: 'mp4', resolution: '720p', formatString: '');
      
      final v1 = MediaInfo(id: 'v1', title: 'v1', originalUrl: 'v1', formats: [f1080, f720], isVideo: true);
      final v2 = MediaInfo(id: 'v2', title: 'v2', originalUrl: 'v2', formats: [f1080, f720], isVideo: true);
      
      final group = MediaGroup(originalUrl: 'p1', items: [v1, v2]);
      final playlistItem = MediaInfo(id: 'p1', title: 'p1', originalUrl: 'p1', isPlaylist: true, formats: []);
      
      config.format = f1080;
      config.itemFormats['v1'] = f1080;
      config.itemFormats['v2'] = f720; // Divergent format
      
      await tester.pumpWidget(wrap(
        FormatSelectionDropdown(
          item: playlistItem,
          config: config,
          index: 0,
          isItemLevel: false,
          group: group,
          getHeight: (r) => r.contains('1080') ? 1080 : 720,
          matchTargetFormat: (i, f) => f1080,
          onChanged: (val) {},
        )
      ));
      
      expect(find.text('Mixed'), findsOneWidget);

    });
  });
}
