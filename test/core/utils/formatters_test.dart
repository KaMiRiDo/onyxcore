import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/formatters.dart';

void main() {
  group('formatDuration', () {
    test('formats durations correctly', () {
      expect(formatDuration(Duration.zero), '00:00');
      expect(formatDuration(const Duration(seconds: 5)), '00:05');
      expect(formatDuration(const Duration(minutes: 12, seconds: 34)), '12:34');
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '62:03');
    });
  });

  group('formatDurationMs', () {
    test('formats durations with milliseconds correctly', () {
      expect(formatDurationMs(Duration.zero), '00:00:00.000');
      expect(
        formatDurationMs(
          const Duration(hours: 2, minutes: 15, seconds: 45, milliseconds: 789),
        ),
        '02:15:45.789',
      );
    });
  });

  group('bytesToHumanReadable', () {
    test('formats bytes to KB, MB, GB correctly', () {
      expect(bytesToHumanReadable(0), '0 B');
      expect(bytesToHumanReadable(500), '500 B');
      expect(bytesToHumanReadable(1024), '1024 B');
      expect(bytesToHumanReadable(1025), '1.0 KB');
      expect(bytesToHumanReadable(1024 * 1024 * 5), '5.0 MB');
      expect(bytesToHumanReadable(1024 * 1024 * 1024 * 3), '3.0 GB');
    });
  });

  group('truncateMiddle', () {
    test('returns original string if within limit', () {
      expect(truncateMiddle('short.txt', maxLength: 15), 'short.txt');
    });

    test('truncates middle preserving short extension', () {
      expect(
        truncateMiddle('very_long_file_name_with_lots_of_words.pdf', maxLength: 20),
        'very_long_fil....pdf',
      );
    });

    test('does not preserve extension if extension is too long', () {
      expect(
        truncateMiddle('very_long_file_name_with_lots_of_words.extensionlong', maxLength: 20),
        'very_long_file_na...',
      );
    });

    test('handles files with no extension', () {
      expect(
        truncateMiddle('very_long_file_name_without_extension', maxLength: 20),
        'very_long_file_na...',
      );
    });
  });
}
