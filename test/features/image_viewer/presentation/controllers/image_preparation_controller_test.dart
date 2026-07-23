import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_preparation_controller.dart';

void main() {
  group('ImagePreparationController', () {
    late ImagePreparationController controller;
    late Map<String, Completer<String?>> converterCompleters;
    late List<String> conversionCalls;
    
    Future<String?> mockConverter(String sourcePath) {
      conversionCalls.add(sourcePath);
      final completer = Completer<String?>();
      converterCompleters[sourcePath] = completer;
      return completer.future;
    }

    setUp(() {
      converterCompleters = {};
      conversionCalls = [];
      controller = ImagePreparationController(converter: mockConverter);
    });

    tearDown(() {
      try {
        controller.dispose();
      } catch (_) {}
    });

    test('initial state is correct', () {
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, isNull);
    });

    test('normal image does not trigger conversion', () async {
      await controller.prepare('image.jpg');
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, isNull);
      expect(conversionCalls, isEmpty);
    });

    test('special format triggers conversion and updates state on success', () async {
      final prepareFuture = controller.prepare('image.heic');
      
      expect(controller.isConverting, isTrue);
      expect(controller.preparedPath, isNull);
      expect(conversionCalls, contains('image.heic'));
      
      converterCompleters['image.heic']!.complete('temp/image.heic.jpg');
      await prepareFuture;
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, equals('temp/image.heic.jpg'));
    });

    test('special format triggers conversion and updates state on failure', () async {
      final prepareFuture = controller.prepare('image.raw');
      
      expect(controller.isConverting, isTrue);
      expect(controller.preparedPath, isNull);
      
      converterCompleters['image.raw']!.complete(null);
      await prepareFuture;
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, isNull);
    });

    test('switching from special to normal image resets state', () async {
      // 1. Prepare special image
      final prepareFuture = controller.prepare('image.heic');
      converterCompleters['image.heic']!.complete('temp/image.heic.jpg');
      await prepareFuture;
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, equals('temp/image.heic.jpg'));
      
      // 2. Switch to normal image
      await controller.prepare('image.jpg');
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, isNull);
    });

    test('rapid media switching prevents stale results (race condition guard)', () async {
      // 1. Start preparing first image (slow)
      final prepare1 = controller.prepare('slow.heic');
      expect(controller.isConverting, isTrue);
      
      // 2. User quickly navigates to second image (fast)
      final prepare2 = controller.prepare('fast.dng');
      
      // 3. Fast image finishes converting
      converterCompleters['fast.dng']!.complete('temp/fast.dng.jpg');
      await prepare2;
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, equals('temp/fast.dng.jpg'));
      
      // 4. Slow image finally finishes converting
      converterCompleters['slow.heic']!.complete('temp/slow.heic.jpg');
      await prepare1;
      
      // The state should NOT be overwritten by the stale result
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, equals('temp/fast.dng.jpg'));
    });

    test('reset clears state', () async {
      final prepareFuture = controller.prepare('image.heic');
      converterCompleters['image.heic']!.complete('temp/image.heic.jpg');
      await prepareFuture;
      
      controller.reset();
      
      expect(controller.isConverting, isFalse);
      expect(controller.preparedPath, isNull);
    });
    
    test('dispose prevents state updates', () async {
      final prepareFuture = controller.prepare('image.heic');
      
      controller.dispose();
      
      // Complete after disposal
      converterCompleters['image.heic']!.complete('temp/image.heic.jpg');
      await prepareFuture;
      
      // Should not throw or update (we can't easily assert non-notification here, 
      // but it shouldn't crash with "A ImagePreparationController was used after being disposed")
    });
  });
}
