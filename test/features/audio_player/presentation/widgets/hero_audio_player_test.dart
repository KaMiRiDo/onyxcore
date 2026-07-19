// ignore_for_file: cascade_invocations
import 'dart:ui' as ui;

import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/hero_audio_player.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

class DummyAudioFavoritesNotifier extends AudioFavoritesNotifier {
  @override
  void setRef(Ref ref) {} // Override setRef to do nothing, avoiding databaseProvider access
}

Future<Uint8List> createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), ui.Paint()..color = Colors.black);
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List validPngBytes;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        return null;
      },
    );
    MediaKit.ensureInitialized();
    validPngBytes = await createTestImage();
  });

  Widget buildTestWidget({
    required FileItem? currentTrack,
    Tag? tag,
  }) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentTrackProvider.overrideWith((ref) => currentTrack),
        audioTagsProvider.overrideWith((ref, arg) => Future.value(tag)),
        audioFavoritesProvider.overrideWith((ref) => DummyAudioFavoritesNotifier()),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: HeroAudioPlayer(),
        ),
      ),
    );
  }

  group('HeroAudioPlayer', () {
    testWidgets('renders nothing when currentTrack is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(currentTrack: null));
      expect(find.byType(SizedBox), findsWidgets);
      // Wait for timers
      await tester.pump(const Duration(seconds: 3));
      
      // Clean up the widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('renders properly with a currentTrack without tags', (tester) async {
      final file = FileItem(
        path: '/test.mp3',
        name: 'test.mp3',
        type: FileItemType.audio,
        modified: DateTime.now(),
        sizeBytes: 100,
      );
      await tester.pumpWidget(buildTestWidget(currentTrack: file));
      expect(find.text('test'), findsWidgets);
      expect(find.text('Audio File'), findsWidgets);

      // Wait to trigger AutoScrollingText ticker
      await tester.pump(const Duration(seconds: 3));
      
      // Clean up the widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('renders properly with a currentTrack with tags', (tester) async {
      final file = FileItem(
        path: '/test.mp3',
        name: 'test.mp3',
        type: FileItemType.audio,
        modified: DateTime.now(),
        sizeBytes: 100,
      );
      final tag = Tag(
        trackArtist: 'Test Artist',
        album: 'Test Album',
        pictures: [
          Picture(
            pictureType: PictureType.coverFront,
            mimeType: MimeType.png,
            bytes: validPngBytes,
          )
        ],
      );

      await tester.pumpWidget(buildTestWidget(currentTrack: file, tag: tag));
      await tester.pump(const Duration(seconds: 3));

      // Update the widget to trigger didUpdateWidget
      final file2 = FileItem(
        path: '/test2.mp3',
        name: 'test2.mp3',
        type: FileItemType.audio,
        modified: DateTime.now(),
        sizeBytes: 100,
      );
      await tester.pumpWidget(buildTestWidget(currentTrack: file2, tag: tag));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));

      // Clean up the widget tree to kill tickers
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('AutoScrollingText didUpdateWidget is covered', (tester) async {
      Widget buildAutoScrollingText(String text) {
        return MaterialApp(
          home: Scaffold(
            body: AutoScrollingText(
              text: text,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildAutoScrollingText('Text 1'));
      await tester.pump(const Duration(seconds: 3));
      
      // Update with new text
      await tester.pumpWidget(buildAutoScrollingText('Text 2'));
      await tester.pump(const Duration(seconds: 3));

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
