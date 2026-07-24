import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_hud_controller.dart';

void main() {
  group('ImageHudController', () {
    late ImageHudController controller;
    var listenerCount = 0;

    setUp(() {
      controller = ImageHudController();
      listenerCount = 0;
      controller.addListener(() {
        listenerCount++;
      });
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is correct', () {
      expect(controller.isControlsVisible, false);
      expect(controller.isClosing, false);
      expect(controller.showZoomIndicator, false);
    });

    test('showControls updates state and notifies listeners', () {
      controller.showControls();
      expect(controller.isControlsVisible, true);
      expect(listenerCount, 1);
    });

    test('hideControls updates state and notifies listeners', () {
      controller.showControls();
      listenerCount = 0; // reset
      controller.hideControls();
      expect(controller.isControlsVisible, false);
      expect(listenerCount, 1);
    });

    test('toggleControls updates state and notifies listeners', () {
      controller.toggleControls();
      expect(controller.isControlsVisible, true);
      expect(listenerCount, 1);

      controller.toggleControls();
      expect(controller.isControlsVisible, false);
      expect(listenerCount, 2);
    });



    test('startHideTimer hides controls after 3 seconds', () async {
      controller.showControls();
      expect(controller.isControlsVisible, true);

      controller.startHideTimer();

      await Future<void>.delayed(const Duration(seconds: 4));
      expect(controller.isControlsVisible, false);
    });

    test('showZoomIndicatorForDuration shows indicator for 2 seconds', () async {
      controller.showZoomIndicatorForDuration();
      expect(controller.showZoomIndicator, true);

      await Future<void>.delayed(const Duration(seconds: 3));
      expect(controller.showZoomIndicator, false);
    });

    test('startClosing sets isClosing to true', () {
      controller.startClosing();
      expect(controller.isClosing, true);
      expect(listenerCount, 1);
    });
  });
}
