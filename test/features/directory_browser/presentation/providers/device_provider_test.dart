import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';

void main() {
  group('DeviceProvider', () {
    test('devicesStreamProvider yields data', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      final sub = container.listen(deviceProvider, (_, __) {});
      
      final devices = await container.read(deviceProvider.future);
      expect(devices, isNotNull);
      
      // Wait for a few polling cycles
      await Future<void>.delayed(const Duration(seconds: 3));
      
      sub.close();
    });
  });
}
