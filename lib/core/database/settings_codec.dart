import 'dart:convert';

import 'package:onyxcore/core/database/app_database.dart' show AppDatabase, Settings;

/// Centralized helpers for encoding/decoding values stored in the [Settings]
/// Drift table. All settings serialization goes through these helpers so that
/// codec logic is never re-implemented at individual call sites.
abstract final class SettingsCodec {
  // ── Scalars ─────────────────────────────────────────────────────────────

  static String encodeBool(bool v) => v ? '1' : '0';
  static bool decodeBool(String? raw, {required bool fallback}) {
    if (raw == null) return fallback;
    return raw == '1';
  }

  static String encodeInt(int v) => v.toString();
  static int decodeInt(String? raw, {required int fallback}) {
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  static String encodeDouble(double v) => v.toString();
  static double decodeDouble(String? raw, {required double fallback}) {
    if (raw == null) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  static String encodeString(String v) => v;
  static String decodeString(String? raw, {required String fallback}) =>
      raw ?? fallback;

  // ── Nullable scalars ─────────────────────────────────────────────────────

  /// Encode a nullable String. Returns null if [v] is null (caller should
  /// call [AppDatabase.removeSetting] instead of storing).
  static String? encodeNullableString(String? v) => v;
  static String? decodeNullableString(String? raw) => raw;

  // ── JSON helpers (for Map/List values) ──────────────────────────────────

  static String encodeJson(Object v) => jsonEncode(v);

  static Map<String, dynamic> decodeJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static List<dynamic> decodeJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }
}
