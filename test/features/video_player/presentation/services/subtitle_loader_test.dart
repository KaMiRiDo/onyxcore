import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/video_player/presentation/services/subtitle_loader.dart';

class MockPlayer extends Mock implements Player {}

class FakeSubtitleTrack extends Fake implements SubtitleTrack {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSubtitleTrack());
  });

  group('SubtitleLoader', () {
    late MockPlayer mockPlayer;
    late Directory tempDir;

    setUp(() {
      mockPlayer = MockPlayer();
      when(() => mockPlayer.setSubtitleTrack(any())).thenAnswer((_) async {});
      tempDir = Directory.systemTemp.createTempSync('subtitle_loader_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('autoLoadExternalSubtitles loads .srt file if exists', () async {
      final videoPath = '${tempDir.path}/video.mp4';
      final srtPath = '${tempDir.path}/video.srt';
      
      File(videoPath).createSync();
      File(srtPath).createSync();

      await SubtitleLoader.autoLoadExternalSubtitles(
        player: mockPlayer,
        videoPath: videoPath,
      );

      verify(() => mockPlayer.setSubtitleTrack(any())).called(1);
    });

    test('autoLoadExternalSubtitles loads .vtt file if exists', () async {
      final videoPath = '${tempDir.path}/video.mkv';
      final vttPath = '${tempDir.path}/video.vtt';
      
      File(videoPath).createSync();
      File(vttPath).createSync();

      await SubtitleLoader.autoLoadExternalSubtitles(
        player: mockPlayer,
        videoPath: videoPath,
      );

      verify(() => mockPlayer.setSubtitleTrack(any())).called(1);
    });

    test('autoLoadExternalSubtitles loads .ass file if exists', () async {
      final videoPath = '${tempDir.path}/video.avi';
      final assPath = '${tempDir.path}/video.ass';
      
      File(videoPath).createSync();
      File(assPath).createSync();

      await SubtitleLoader.autoLoadExternalSubtitles(
        player: mockPlayer,
        videoPath: videoPath,
      );

      verify(() => mockPlayer.setSubtitleTrack(any())).called(1);
    });

    test('autoLoadExternalSubtitles does nothing if no subtitles exist', () async {
      final videoPath = '${tempDir.path}/video.mp4';
      
      File(videoPath).createSync();

      await SubtitleLoader.autoLoadExternalSubtitles(
        player: mockPlayer,
        videoPath: videoPath,
      );

      verifyNever(() => mockPlayer.setSubtitleTrack(any()));
    });
    
    test('autoLoadExternalSubtitles catches exception gracefully', () async {
      await SubtitleLoader.autoLoadExternalSubtitles(
        player: mockPlayer,
        videoPath: '', // This will throw on file.parent or p.basename
      );

      verifyNever(() => mockPlayer.setSubtitleTrack(any()));
    });
  });
}
