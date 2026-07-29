import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/extensions.dart';

void main() {
  group('IntExtensions', () {
    test('toHumanReadableSize formats bytes correctly', () {
      expect(0.toHumanReadableSize(), '0 B');
      expect(1024.toHumanReadableSize(), '1024 B');
      expect(1025.toHumanReadableSize(), '1.0 KB');
      expect((1024 * 1024 * 5).toHumanReadableSize(), '5.0 MB');
      expect((1024 * 1024 * 1024 * 2).toHumanReadableSize(), '2.0 GB');
    });
  });

  group('DurationExtensions', () {
    test('toMmSs formats as MM:SS', () {
      expect(const Duration(seconds: 45).toMmSs(), '00:45');
      expect(const Duration(minutes: 3, seconds: 45).toMmSs(), '03:45');
      expect(const Duration(hours: 1, minutes: 2, seconds: 3).toMmSs(), '62:03');
    });

    test('toHhMmSsMss formats as HH:MM:SS.MMM', () {
      expect(const Duration(seconds: 45).toHhMmSsMss(), '00:00:45.000');
      expect(
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 123)
            .toHhMmSsMss(),
        '01:02:03.123',
      );
    });
  });

  group('StringExtensions', () {
    test('fileExtension returns lowercase extension with dot', () {
      expect('file.TXT'.fileExtension, '.txt');
      expect('path/to/file.tar.gz'.fileExtension, '.gz');
      expect('no_extension'.fileExtension, '');
    });

    test('baseName returns file name with extension', () {
      expect('path/to/file.txt'.baseName, 'file.txt');
      expect('/file.txt'.baseName, 'file.txt');
    });
  });
}
