import 'package:fake_async/fake_async.dart';
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



    test('startHideTimer hides controls after 3 seconds', () {
      fakeAsync((async) {
        controller.showControls();
        expect(controller.isControlsVisible, true);

        controller.startHideTimer();

        async.elapse(const Duration(seconds: 4));
        expect(controller.isControlsVisible, false);
      });
    });

    test('showZoomIndicatorForDuration shows indicator for 2 seconds', () {
      fakeAsync((async) {
        controller.showZoomIndicatorForDuration();
        expect(controller.showZoomIndicator, true);

        async.elapse(const Duration(seconds: 3));
        expect(controller.showZoomIndicator, false);
      });
    });

    test('showZoomIndicatorForDuration does not spam notifyListeners on repeated calls', () {
      fakeAsync((async) {
        // Initial state
        expect(controller.showZoomIndicator, false);

        // First call should show indicator and notify once
        controller.showZoomIndicatorForDuration();
        expect(controller.showZoomIndicator, true);
        expect(listenerCount, 1);

        // Repeated calls while still visible should NOT notify again
        controller
          ..showZoomIndicatorForDuration()
          ..showZoomIndicatorForDuration();
        expect(controller.showZoomIndicator, true);
        expect(listenerCount, 1, reason: 'Repeated calls should not notify if already visible');

        // Advance time just before expiry
        async.elapse(const Duration(milliseconds: 1999));
        expect(controller.showZoomIndicator, true);
        expect(listenerCount, 1);

        // One more call to extend timer
        controller.showZoomIndicatorForDuration();
        expect(listenerCount, 1);

        // Original 2 seconds expire, but we extended it, so it should still be visible
        async.elapse(const Duration(milliseconds: 10));
        expect(controller.showZoomIndicator, true);
        expect(listenerCount, 1);

        // Wait for the new timer to expire
        async.elapse(const Duration(seconds: 2));
        expect(controller.showZoomIndicator, false);
        expect(listenerCount, 2, reason: 'Should notify exactly once when hidden');
      });
    });

    test('startClosing sets isClosing to true', () {
      controller.startClosing();
      expect(controller.isClosing, true);
      expect(listenerCount, 1);
    });
  });
}
