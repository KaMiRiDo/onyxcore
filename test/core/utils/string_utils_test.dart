import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/string_utils.dart';

void main() {
  group('StringUtils.truncateMiddle', () {
    test('returns original string if within limit', () {
      expect(StringUtils.truncateMiddle('hello', maxLength: 10), 'hello');
    });

    test('truncates in the middle keeping start and end parts', () {
      expect(StringUtils.truncateMiddle('abcdefghijklmnopqrstuvwxyz', maxLength: 13), 'abcde...vwxyz');
    });
  });

  group('StringUtils.formatBytes', () {
    test('formats bytes to human-readable size correctly', () {
      expect(StringUtils.formatBytes(0), '0 B');
      expect(StringUtils.formatBytes(-5), '0 B');
      expect(StringUtils.formatBytes(500), '500.0 B');
      expect(StringUtils.formatBytes(1024), '1.0 KB');
      expect(StringUtils.formatBytes(1024 * 1024 * 5), '5.0 MB');
      expect(StringUtils.formatBytes(1024 * 1024 * 1024 * 3), '3.0 GB');
      expect(StringUtils.formatBytes(1024 * 1024 * 1024 * 1024 * 4), '4.0 TB');
    });
  });
}
