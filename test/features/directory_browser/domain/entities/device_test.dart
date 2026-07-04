import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/device.dart';

void main() {
  group('Device', () {
    test('should correctly assign fields through constructor', () {
      final device = Device(
        id: '/dev/sda1',
        name: 'USB Drive',
        path: '/media/usb',
        size: '16 GB',
        usage: 0.5,
        isRemovable: true,
        isMobile: true,
      );

      expect(device.id, '/dev/sda1');
      expect(device.name, 'USB Drive');
      expect(device.path, '/media/usb');
      expect(device.size, '16 GB');
      expect(device.usage, 0.5);
      expect(device.isRemovable, true);
      expect(device.isMobile, true);
    });

    test('should use default false for isMobile if not provided', () {
      final device = Device(
        id: '/dev/sda2',
        name: 'Main Drive',
        path: '/',
        size: '500 GB',
        usage: 0.8,
        isRemovable: false,
      );

      expect(device.isMobile, false);
    });
  });
}
