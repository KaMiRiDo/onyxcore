class Device {
  final String id; // System identifier (e.g., /dev/sdb1)
  final String name;
  final String path;
  final String size;
  final double usage; // 0.0 to 1.0
  final bool isRemovable;
  final bool isMobile;

  Device({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.usage,
    required this.isRemovable,
    this.isMobile = false,
  });
}
