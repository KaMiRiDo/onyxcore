import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/deno_runtime.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

void main() {
  group('EngineRegistry + Deno tests', () {
    test('Deno is included in missingRequired when not installed', () {
      EngineRegistry.clearRegisteredEngines();
      
      // If Deno is not installed, it should be in missingRequired
      // Note: In tests it might actually be missing, so this will be true.
      final missing = EngineRegistry.missingRequired;
      final hasDeno = missing.any((e) => e.id == 'deno');
      
      // We expect it to be there if it's missing on disk. 
      // If it is installed, it shouldn't be there. We just test that the logic doesn't crash.
      expect(hasDeno, !DenoRuntime.instance.isInstalled);
    });

    test('allRequiredReady factors in Deno', () {
      expect(
        EngineRegistry.allRequiredReady,
        EngineRegistry.requiredInstalled && DenoRuntime.instance.isInstalled
      );
    });
  });
}
