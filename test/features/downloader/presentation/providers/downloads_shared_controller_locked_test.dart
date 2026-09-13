import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/services/dml_crypto_service.dart';

void main() {
  group('DownloadsSharedController Locked Import', () {
    late ProviderContainer container;
    late DownloadsSharedController controller;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          // Mock the database if necessary, for edge testing it may not be strictly required to have a real one
        ],
      );
      controller = container.read(downloadsSharedControllerProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('importListFromFile sets isLocked and parsedItems to null for locked DML', () async {
      // 1. Create a password-locked DML file
      final tempDir = Directory.systemTemp.createTempSync('locked_dml_test');
      final file = File('${tempDir.path}/locked_list.dml');
      
      const password = 'test_password';
      const payload = '{"items": []}';
      final encryptedBytes = DmlCryptoService.encrypt(payload, password: password);
      await file.writeAsBytes(encryptedBytes);

      // 2. Attempt to import it without a password
      await controller.importListFromFile(file.path, 'locked_list');
      
      // 3. Verify cache state
      expect(controller.cache.isLocked, isTrue);
      expect(controller.cache.parsedItems, isNull);
      expect(controller.cache.importedListPath, equals(file.path));

      // 4. Attempt to import with correct password
      await controller.importListFromFile(file.path, 'locked_list', password: password);
      
      // 5. Verify cache state
      expect(controller.cache.isLocked, isFalse);
      expect(controller.cache.parsedItems, isNotNull);
      expect(controller.cache.currentPassword, equals(password));

      // Cleanup
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
