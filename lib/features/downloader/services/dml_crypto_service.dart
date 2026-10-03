import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

// ── Custom Exception ─────────────────────────────────────────────────────────

class DmlLockedException implements Exception {
  const DmlLockedException([this.message = 'DML file is locked']);
  final String message;
  @override
  String toString() => 'DmlLockedException: $message';
}

// ── Isolate Parameter Classes ────────────────────────────────────────────────

class _EncryptParams {
  const _EncryptParams(this.jsonPayload, this.password);
  final String jsonPayload;
  final String? password;
}

class _DecryptParams {
  const _DecryptParams(this.dmlBytes, this.password);
  final Uint8List dmlBytes;
  final String? password;
}

// ── Top-level functions required by compute() (cannot be closures) ────────────

Uint8List _encryptIsolateEntry(_EncryptParams params) =>
    DmlCryptoService.encrypt(params.jsonPayload, password: params.password);

String _decryptIsolateEntry(_DecryptParams params) =>
    DmlCryptoService.decrypt(params.dmlBytes, password: params.password);

// ─────────────────────────────────────────────────────────────────────────────

class DmlCryptoService {
  // App-internal key for DML encryption.
  static const _appSecret = 'OnyxCoreDMLKey_2026_SecureStorage!';

  static final Uint8List _magicBytes =
      Uint8List.fromList([0x44, 0x4D, 0x4C, 0x01]); // "DML\x01"
      
  static final Uint8List _magicBytesLocked =
      Uint8List.fromList([0x44, 0x4D, 0x4C, 0x02]); // "DML\x02"

  // ── Sync (for small payloads or already-isolated callers) ─────────────────

  static Uint8List encrypt(String jsonPayload, {String? password}) {
    final payloadBytes = utf8.encode(jsonPayload);
    final iv = _generateRandomBytes(12); // GCM standard IV size
    final key = _deriveKey(password ?? _appSecret);
    final isLocked = password != null;

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // MAC size in bits
          iv,
          Uint8List(0), // No AAD
        ),
      );

    final ciphertext = cipher.process(Uint8List.fromList(payloadBytes));

    final builder = BytesBuilder(copy: false)
      ..add(isLocked ? _magicBytesLocked : _magicBytes)
      ..add(iv)
      ..add(ciphertext);

    return builder.takeBytes();
  }

  static String decrypt(Uint8List dmlBytes, {String? password}) {
    if (dmlBytes.length < 4 + 12 + 16) {
      throw const FormatException('Invalid DML file: too short');
    }

    var isLocked = true;
    var isDefault = true;
    // Check magic bytes
    for (var i = 0; i < 4; i++) {
      if (dmlBytes[i] != _magicBytesLocked[i]) isLocked = false;
      if (dmlBytes[i] != _magicBytes[i]) isDefault = false;
    }
    
    if (!isLocked && !isDefault) {
      throw const FormatException('Invalid DML file: incorrect magic bytes');
    }

    if (isLocked && password == null) {
      throw const DmlLockedException('Password required');
    }

    final iv = dmlBytes.sublist(4, 4 + 12);
    final ciphertext = dmlBytes.sublist(4 + 12);
    final key = _deriveKey(password ?? _appSecret);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          128, // MAC size in bits
          iv,
          Uint8List(0), // No AAD
        ),
      );

    try {
      final plaintext = cipher.process(ciphertext);
      return utf8.decode(plaintext);
    } catch (e) {
      if (isLocked && password != null) {
        throw const DmlLockedException('Incorrect password');
      }
      throw const FormatException(
          'Failed to decrypt DML file (tampered or corrupt)');
    }
  }

  // ── Async isolate variants (use these from the UI thread) ─────────────────

  /// Encrypts [jsonPayload] on a background isolate so the UI stays responsive.
  static Future<Uint8List> encryptInIsolate(String jsonPayload, {String? password}) =>
      compute(_encryptIsolateEntry, _EncryptParams(jsonPayload, password));

  /// Decrypts [dmlBytes] on a background isolate so the UI stays responsive.
  static Future<String> decryptInIsolate(Uint8List dmlBytes, {String? password}) =>
      compute(_decryptIsolateEntry, _DecryptParams(dmlBytes, password));

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool isDmlFile(String path) =>
      path.toLowerCase().endsWith('.dml');

  static bool isJsonFile(String path) =>
      path.toLowerCase().endsWith('.json');

  static Uint8List _deriveKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
