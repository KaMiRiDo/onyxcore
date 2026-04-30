class Device {
  final String name;
  final String path;
  final String size;
  final double usage; // 0.0 to 1.0
  final bool isRemovable;

  Device({
    required this.name,
    required this.path,
    required this.size,
    required this.usage,
    required this.isRemovable,
  });
}
