import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/dml_crypto_service.dart';

void main() {
  group('DmlCryptoService', () {
    const payload = '{"items": []}';
    
    test('encrypts and decrypts with default password', () {
      final encrypted = DmlCryptoService.encrypt(payload);
      final decrypted = DmlCryptoService.decrypt(encrypted);
      expect(decrypted, equals(payload));
    });

    test('encrypts with custom password and decrypts with same password', () {
      const password = 'my_super_secret_password';
      final encrypted = DmlCryptoService.encrypt(payload, password: password);
      final decrypted = DmlCryptoService.decrypt(encrypted, password: password);
      expect(decrypted, equals(payload));
    });

    test('decrypting locked file without password throws DmlLockedException', () {
      const password = 'my_super_secret_password';
      final encrypted = DmlCryptoService.encrypt(payload, password: password);
      
      expect(
        () => DmlCryptoService.decrypt(encrypted),
        throwsA(isA<DmlLockedException>()),
      );
    });

    test('decrypting locked file with wrong password throws DmlLockedException', () {
      const password = 'my_super_secret_password';
      final encrypted = DmlCryptoService.encrypt(payload, password: password);
      
      expect(
        () => DmlCryptoService.decrypt(encrypted, password: 'wrong_password'),
        throwsA(isA<DmlLockedException>()),
      );
    });
    
    test('decrypting corrupted file throws FormatException', () {
      final encrypted = DmlCryptoService.encrypt(payload);
      // Corrupt the ciphertext
      encrypted[encrypted.length - 1] ^= 0xFF;
      
      expect(
        () => DmlCryptoService.decrypt(encrypted),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
