import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

void main() {
  group('Downloads Shared Dropdowns Widget Tests', () {
    testWidgets('EngineSelectorDropdown renders correctly and updates', (WidgetTester tester) async {
      String selectedEngine = 'auto';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return EngineSelectorDropdown(
                  selectedEngine: selectedEngine,
                  onChanged: (val) {
                    setState(() {
                      selectedEngine = val;
                    });
                  },
                );
              }
            ),
          ),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.text('Auto Select'), findsOneWidget);

      await tester.tap(find.byType(EngineSelectorDropdown));
      await tester.pumpAndSettle();

      // Check if yt-dlp is in the list
      expect(find.text('yt-dlp'), findsOneWidget);

      await tester.tap(find.text('yt-dlp'));
      await tester.pumpAndSettle();

      expect(selectedEngine, 'yt-dlp');
      expect(find.text('yt-dlp'), findsOneWidget); // Label changed
    });

    testWidgets('GroupFilterDropdown renders correctly and updates', (WidgetTester tester) async {
      GroupDownloadType filter = GroupDownloadType.all;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return GroupFilterDropdown(
                  selectedFilter: filter,
                  isEnabled: true,
                  onChanged: (val) {
                    setState(() {
                      filter = val;
                    });
                  },
                );
              }
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      await tester.tap(find.byType(GroupFilterDropdown));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Videos Only').last); // .last because it may find multiple?
      await tester.pumpAndSettle();

      expect(filter, GroupDownloadType.videos);
      expect(find.text('Videos Only'), findsOneWidget);
    });
  });
}
