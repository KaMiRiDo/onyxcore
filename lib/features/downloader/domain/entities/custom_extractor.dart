import 'package:flutter/foundation.dart';

@immutable
class CustomExtractor {
  const CustomExtractor({
    required this.id,
    required this.name,
    required this.script,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory CustomExtractor.fromMap(Map<String, dynamic> map) {
    return CustomExtractor(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      script: map['script']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['createdAt'] as num).toInt()),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch((map['modifiedAt'] as num).toInt()),
    );
  }

  final String id;
  final String name;
  final String script;
  final DateTime createdAt;
  final DateTime modifiedAt;

  CustomExtractor copyWith({
    String? id,
    String? name,
    String? script,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return CustomExtractor(
      id: id ?? this.id,
      name: name ?? this.name,
      script: script ?? this.script,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'script': script,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'modifiedAt': modifiedAt.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is CustomExtractor &&
      other.id == id &&
      other.name == name &&
      other.script == script &&
      other.createdAt.millisecondsSinceEpoch == createdAt.millisecondsSinceEpoch &&
      other.modifiedAt.millisecondsSinceEpoch == modifiedAt.millisecondsSinceEpoch;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      script.hashCode ^
      createdAt.hashCode ^
      modifiedAt.hashCode;
  }
}
