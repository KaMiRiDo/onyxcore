import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/filter_sort_button.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockAppDatabase extends Mock implements AppDatabase {
  MockAppDatabase() {
    when(getAudioFavorites).thenAnswer((_) async => <String>{});
    when(() => pruneMetadataCache(any())).thenAnswer((_) async => <String>[]);
    when(getAllMetadataCache).thenAnswer((_) async => <MetadataCacheEntry>[]);
    when(getAllThumbnailEntries).thenAnswer((_) async => <ThumbnailCacheEntry>[]);
    when(() => getPlaybackPosition(any())).thenAnswer((_) async => null);
    when(() => savePlaybackPosition(any(), any())).thenAnswer((_) async {});
  }
}

class MockSettingsNotifierEnabled extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(audioFilterSortEnabled: true);
}

class MockSettingsNotifierDisabled extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

void main() {
  setUpAll(MediaKit.ensureInitialized);

  group('AudioPlayerView Filter/Sort UI', () {
    Widget buildWidget({required bool isFilterSortEnabled}) {
      final now = DateTime.now();
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(MockAppDatabase()),
          settingsProvider.overrideWith(isFilterSortEnabled ? MockSettingsNotifierEnabled.new : MockSettingsNotifierDisabled.new),
        ],
        child: MaterialApp(
          home: AudioPlayerView(
            item: FileItem(
              path: '/mock/audio.mp3',
              name: 'audio.mp3',
              sizeBytes: 1000,
              modified: now,
              type: FileItemType.audio,
            ),
            isStandalone: true,
          ),
        ),
      );
    }

    testWidgets('shows FilterSortButton when audioFilterSortEnabled is true', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(isFilterSortEnabled: true));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(FilterSortButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('hides FilterSortButton when audioFilterSortEnabled is false', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(isFilterSortEnabled: false));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(FilterSortButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('FilterSortButton is positioned at bottom right', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(isFilterSortEnabled: true));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(FilterSortButton), findsOneWidget);

      final positionedFinder = find.ancestor(
        of: find.byType(FilterSortButton),
        matching: find.byType(Positioned),
      );
      expect(positionedFinder, findsOneWidget);

      final positioned = tester.widget<Positioned>(positionedFinder);
      expect(positioned.bottom, equals(24));
      expect(positioned.right, equals(24));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('shows empty state when last audio is filter-sorted', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create a real file so MediaFilterService doesn't fail
      final tempDir = Directory.systemTemp.createTempSync('audio_test');
      final mockFile = File('${tempDir.path}/audio.mp3')..createSync();
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final now = DateTime.now();
      final widget = ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(MockAppDatabase()),
          settingsProvider.overrideWith(MockSettingsNotifierEnabled.new),
        ],
        child: MaterialApp(
          home: AudioPlayerView(
            item: FileItem(
              path: mockFile.path,
              name: 'audio.mp3',
              sizeBytes: 1000,
              modified: now,
              type: FileItemType.audio,
            ),
            isStandalone: true,
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(widget);
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      final btn = tester.widget<FilterSortButton>(find.byType(FilterSortButton));
      await tester.runAsync(() async {
        btn.onPressed();
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      // The UI should show the empty state text
      expect(find.text('No audio files to play next.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
