import 'package:flutter/foundation.dart';

@immutable
class CustomExtractor {
  const CustomExtractor({
    required this.id,
    required this.name,
    required this.script,
    required this.createdAt,
    required this.modifiedAt,
    this.metadata,
  });

  factory CustomExtractor.fromMap(Map<String, dynamic> map) {
    return CustomExtractor(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      script: map['script']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['modifiedAt'] as num).toInt(),
            )
          : DateTime.now(),
      // Phase 2: optional metadata for default extractors.
      // Absent or explicit null → null (Phase 1 script extractors).
      metadata: map['metadata']?.toString(),
    );
  }

  final String id;
  final String name;

  /// The JavaScript extractor script executed by the runtime.
  ///
  /// For manual script extractors this is user-authored code.
  /// For default extractors (Phase 2+) this is generated from a template;
  /// the original configuration is preserved in [metadata].
  final String script;

  final DateTime createdAt;
  final DateTime modifiedAt;

  /// Optional JSON metadata for default extractor configuration.
  ///
  /// - null  → this is a manual script extractor (Phase 1 / Script tab).
  /// - non-null → JSON object containing at minimum `extractorKind`,
  ///              and kind-specific fields (e.g. `cssSelector`,
  ///              `attributeName` for the HTML extractor).
  ///
  /// Parse with [DefaultExtractorTemplateService.decodeMetadata].
  /// Treat malformed or null metadata defensively — never crash.
  final String? metadata;

  CustomExtractor copyWith({
    String? id,
    String? name,
    String? script,
    DateTime? createdAt,
    DateTime? modifiedAt,
    // Use Object? sentinel so null can be passed explicitly to clear metadata.
    Object? metadata = _absent,
  }) {
    return CustomExtractor(
      id: id ?? this.id,
      name: name ?? this.name,
      script: script ?? this.script,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      metadata:
          identical(metadata, _absent) ? this.metadata : metadata as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'script': script,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'modifiedAt': modifiedAt.millisecondsSinceEpoch,
      // Omit metadata key entirely when null so that Phase 1 round-trips
      // produce an identical map (no spurious null entry).
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CustomExtractor &&
        other.id == id &&
        other.name == name &&
        other.script == script &&
        other.createdAt.millisecondsSinceEpoch ==
            createdAt.millisecondsSinceEpoch &&
        other.modifiedAt.millisecondsSinceEpoch ==
            modifiedAt.millisecondsSinceEpoch &&
        other.metadata == metadata;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        script.hashCode ^
        createdAt.hashCode ^
        modifiedAt.hashCode ^
        metadata.hashCode;
  }
}

// Sentinel used by copyWith to distinguish "not provided" from explicit null.
const Object _absent = Object();
