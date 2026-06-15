
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/hero_audio_player.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:audiotags/audiotags.dart';
import 'package:riverpod/riverpod.dart' as riverpod;
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  setUpAll(() {
    try {
      import_hive.Hive.init(import_io.Directory.systemTemp.path);
    } catch (_) {}
  });

  final dummyTrack = FileItem(
    name: 'test_song.mp3',
    path: '/path/to/test_song.mp3',
    type: FileItemType.audio,
    modified: DateTime.now(),
  );

  Widget buildTestWidget({List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [...overrides.cast()],
      child: const MaterialApp(
        home: Scaffold(
          body: HeroAudioPlayer(),
        ),
      ),
    );
  }

  group('HeroAudioPlayer', () {
    testWidgets('return SizedBox.shrink when currentTrack is null (W-AUD-HERO-01)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(null),
      ]));

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(HeroAudioPlayer), findsOneWidget);
      // It returns SizedBox.shrink(), which is a ConstrainedBox inside a SizedBox, 
      // but essentially we check there is no Column or Album art
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('display gradient music note fallback when no cover art (W-AUD-HERO-03, W-AUD-HERO-04)', (tester) async {
      final tag = Tag(title: 'Title', pictures: []);
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
        audioTagsProvider(dummyTrack.path).overrideWith((ref) => tag),
      ]));

      // Let the widget build
      await tester.pump();

      // Should find the Icon fallback
      final iconFinder = find.byIcon(Icons.music_note_rounded);
      expect(iconFinder, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.size, 140);
      
      // Should find ShaderMask
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('display track name without extension (W-AUD-HERO-10)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
      ]));

      await tester.pump();

      expect(find.text('test_song'), findsWidgets); // AutoScrollingText creates multiple
    });

    testWidgets('display "Artist | Album" subtitle when both present (W-AUD-HERO-11)', (tester) async {
      final tag = Tag(trackArtist: 'Artist A', album: 'Album B', pictures: []);
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
        audioTagsOverridesProvider(dummyTrack.path).overrideWith((ref) => tag),
      ]));

      await tester.pump();

      expect(find.text('Artist A | Album B'), findsOneWidget);
    });

    testWidgets('display only artist when album is null/empty (W-AUD-HERO-12)', (tester) async {
      final tag = Tag(trackArtist: 'Artist A', pictures: []);
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
        audioTagsOverridesProvider(dummyTrack.path).overrideWith((ref) => tag),
      ]));

      await tester.pump();

      expect(find.text('Artist A'), findsOneWidget);
    });

    testWidgets('display only album when artist is null/empty (W-AUD-HERO-13)', (tester) async {
      final tag = Tag(album: 'Album B', pictures: []);
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
        audioTagsOverridesProvider(dummyTrack.path).overrideWith((ref) => tag),
      ]));

      await tester.pump();

      expect(find.text('Album B'), findsOneWidget);
    });

    testWidgets('display "Audio File" fallback when both artist and album missing (W-AUD-HERO-14)', (tester) async {
      final tag = Tag(title: 'Just Title', pictures: []);
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
        audioTagsOverridesProvider(dummyTrack.path).overrideWith((ref) => tag),
      ]));

      await tester.pump();

      expect(find.text('Audio File'), findsOneWidget);
    });

    testWidgets('prioritize override tag over async tag (W-AUD-HERO-15)', (tester) async {
      final asyncTag = Tag(trackArtist: 'Async Artist', pictures: []);
      final overrideTag = Tag(trackArtist: 'Override Artist', pictures: []);
      
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
        audioTagsProvider(dummyTrack.path).overrideWith((ref) => asyncTag),
        audioTagsOverridesProvider(dummyTrack.path).overrideWith((ref) => overrideTag),
      ]));

      await tester.pump();

      expect(find.text('Override Artist'), findsOneWidget);
      expect(find.text('Async Artist'), findsNothing);
    });
  });

  group('AutoScrollingText', () {
    testWidgets('not start scrolling before 2 seconds (W-AUD-HERO-23)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AutoScrollingText(
            text: 'Test Long Title That Overflows',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ));

      // Wait 1 second
      await tester.pump(const Duration(seconds: 1));
      
      // We can't directly check the private Ticker, but we can verify it doesn't jump
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.controller?.offset, 0.0);
    });

    testWidgets('initialize scrolling after 2 second delay (W-AUD-HERO-22)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AutoScrollingText(
            text: 'Test Long Title That Overflows',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ));

      // Wait 2.1 seconds to trigger ticker
      await tester.pump(const Duration(milliseconds: 2100));
      // Pump one frame of animation
      await tester.pump(const Duration(milliseconds: 16));
      
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.controller!.offset, greaterThan(0.0));
    });

    testWidgets('render as horizontal ListView with NeverScrollableScrollPhysics (W-AUD-HERO-27)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AutoScrollingText(
            text: 'Test',
            style: TextStyle(),
          ),
        ),
      ));

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.scrollDirection, Axis.horizontal);
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('use fixed 36px height SizedBox (W-AUD-HERO-28)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AutoScrollingText(
            text: 'Test',
            style: TextStyle(),
          ),
        ),
      ));

      final sizedBoxFinder = find.descendant(
        of: find.byType(AutoScrollingText),
        matching: find.byType(SizedBox).first,
      );
      
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.height, 36);
    });
  });
}
