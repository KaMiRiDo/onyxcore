import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloader_filter_overlay.dart';

void main() {
  group('DownloaderFilterOverlayWidget Widget Tests', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(
            body: Center(child: child),
          ),
        );

    testWidgets('renders all 6 types (Image, Videos, Group Post, Playlist, Profile, Others)',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          DownloaderFilterOverlayWidget(
            initialSettings: const DownloaderFilterSettings(),
            availableTypes: const {
              DownloaderItemType.image,
              DownloaderItemType.video,
              DownloaderItemType.groupPost,
              DownloaderItemType.playlist,
              DownloaderItemType.profile,
              DownloaderItemType.others,
            },
            availableDates: const {},
            onFilterChanged: (_) {},
            onClose: () {},
          ),
        ),
      );

      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Group Post'), findsOneWidget);
      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Others'), findsOneWidget);
    });

    testWidgets('only enables types present in availableTypes and ignores taps on disabled types',
        (tester) async {
      DownloaderFilterSettings? updatedSettings;

      await tester.pumpWidget(
        wrap(
          DownloaderFilterOverlayWidget(
            initialSettings: const DownloaderFilterSettings(),
            availableTypes: const {
              DownloaderItemType.image,
              DownloaderItemType.video,
            },
            availableDates: const {},
            onFilterChanged: (s) => updatedSettings = s,
            onClose: () {},
          ),
        ),
      );

      // Tapping Playlist (which is disabled) should NOT trigger onFilterChanged
      await tester.tap(find.text('Playlist'));
      await tester.pumpAndSettle();
      expect(updatedSettings, isNull);

      // Tapping Image (which is enabled) should trigger onFilterChanged instantly
      await tester.tap(find.text('Image'));
      await tester.pumpAndSettle();
      expect(updatedSettings, isNotNull);
      expect(updatedSettings!.selectedTypes, contains(DownloaderItemType.image));
    });

    testWidgets('accordion for uploaded date expands and enables only availableDates',
        (tester) async {
      DownloaderFilterSettings? updatedSettings;
      final targetDate = DateTime(2026, 8, 5);

      await tester.pumpWidget(
        wrap(
          DownloaderFilterOverlayWidget(
            initialSettings: const DownloaderFilterSettings(),
            availableTypes: const {DownloaderItemType.image},
            availableDates: {targetDate},
            onFilterChanged: (s) => updatedSettings = s,
            onClose: () {},
          ),
        ),
      );

      // Accordion header should be present
      expect(find.textContaining('UPLOADED DATE', findRichText: true), findsOneWidget);

      // Tap accordion header to expand calendar
      await tester.tap(find.textContaining('UPLOADED DATE', findRichText: true));
      await tester.pumpAndSettle();

      // Find day 5
      final day5Finder = find.text('5');
      expect(day5Finder, findsWidgets);

      // Tap on day 5 (enabled date) -> should trigger callback instantly
      await tester.tap(day5Finder.first);
      await tester.pumpAndSettle();
      expect(updatedSettings, isNotNull);
      expect(updatedSettings!.selectedDates.any((d) => d.day == 5 && d.month == 8 && d.year == 2026), isTrue);
    });

    testWidgets('reset button clears all selections instantly', (tester) async {
      DownloaderFilterSettings? updatedSettings;
      final initial = DownloaderFilterSettings(
        selectedTypes: {DownloaderItemType.video},
        selectedDates: {DateTime(2026, 8, 5)},
      );

      await tester.pumpWidget(
        wrap(
          DownloaderFilterOverlayWidget(
            initialSettings: initial,
            availableTypes: const {DownloaderItemType.video},
            availableDates: {DateTime(2026, 8, 5)},
            onFilterChanged: (s) => updatedSettings = s,
            onClose: () {},
          ),
        ),
      );

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(updatedSettings, isNotNull);
      expect(updatedSettings!.isDefault, isTrue);
    });
  });
}
