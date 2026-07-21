import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/utils/video_player_utils.dart';

void main() {
  group('VideoPlayerUtils', () {
    test('formatDuration formats < 1 hour correctly', () {
      final duration = const Duration(minutes: 5, seconds: 30);
      expect(VideoPlayerUtils.formatDuration(duration), '05:30');
    });

    test('formatDuration formats > 1 hour correctly', () {
      final duration = const Duration(hours: 1, minutes: 5, seconds: 30);
      expect(VideoPlayerUtils.formatDuration(duration), '01:05:30');
    });

    test('formatDuration handles exact hours', () {
      final duration = const Duration(hours: 2);
      expect(VideoPlayerUtils.formatDuration(duration), '02:00:00');
    });

    test('formatDuration handles 0 seconds', () {
      final duration = const Duration();
      expect(VideoPlayerUtils.formatDuration(duration), '00:00');
    });
  });
}
