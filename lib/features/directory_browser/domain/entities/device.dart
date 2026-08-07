import 'package:flutter/foundation.dart';

@immutable
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.usage,
    required this.isRemovable,
    this.isMobile = false,
  });

  final String id; // System identifier (e.g., /dev/sdb1)
  final String name;
  final String path;
  final String size;
  final double usage; // 0.0 to 1.0
  final bool isRemovable;
  final bool isMobile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          path == other.path &&
          size == other.size &&
          (usage - other.usage).abs() < 0.001 &&
          isRemovable == other.isRemovable &&
          isMobile == other.isMobile;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        path,
        size,
        (usage * 1000).round(),
        isRemovable,
        isMobile,
      );
}
