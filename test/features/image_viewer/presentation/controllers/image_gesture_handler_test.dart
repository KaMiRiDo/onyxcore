import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_gesture_handler.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_zoom_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/zoom_animation_engine.dart';

class MockZoomAnimationEngine extends ZoomAnimationEngine {
  MockZoomAnimationEngine() : super(animationController: AnimationController(vsync: const TestVSync()), onTick: (_) {});
}

class MockImageZoomController extends ImageZoomController {
  MockImageZoomController() : super(
    animationEngine: MockZoomAnimationEngine(), // Properly mock ZoomAnimationEngine
    onZoomChanged: () {},
  );
  
  double _mockCurrentScale = 1;
  @override
  double get currentScale => _mockCurrentScale;

  int setZoomCalls = 0;
  int applyTranslationCalls = 0;
  int startPanZoomGestureCalls = 0;
  int endPanZoomGestureCalls = 0;
  int updateScrubGestureCalls = 0;
  int updatePinchGestureCalls = 0;

  @override
  void setZoom(double newScale, {required Offset focalPoint, bool animate = true}) {
    setZoomCalls++;
  }

  @override
  void applyTranslation(Offset delta) {
    applyTranslationCalls++;
  }

  @override
  void startPanZoomGesture(Offset initialPosition) {
    startPanZoomGestureCalls++;
  }

  @override
  void endPanZoomGesture() {
    endPanZoomGestureCalls++;
  }

  @override
  void updateScrubGesture(double dy, Offset focalPoint) {
    updateScrubGestureCalls++;
  }

  @override
  void updatePinchGesture(double scale, Offset focalPoint) {
    updatePinchGestureCalls++;
  }
}

void main() {
  group('ImageGestureHandler', () {
    late MockImageZoomController mockController;
    late ImageGestureHandler handler;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockController = MockImageZoomController();
      handler = ImageGestureHandler(zoomController: mockController);
    });

    test('handlePointerSignal without ctrl zooms if scroll up', () {
      // With HardwareKeyboard mocking being difficult without integration test widget, 
      // we assume default is ctrl NOT pressed.
      
      // Wait, in plain dart test, HardwareKeyboard.instance.logicalKeysPressed is empty.
      final event = PointerScrollEvent(scrollDelta: const Offset(0, 10));
      handler.handlePointerSignal(event);
      
      // If ctrl is not pressed, and scale is 1.0, it shouldn't translate
      expect(mockController.applyTranslationCalls, equals(0));
      expect(mockController.setZoomCalls, equals(0));
      
      // If scale > 1.05, it should translate
      mockController._mockCurrentScale = 2.0;
      handler.handlePointerSignal(event);
      expect(mockController.applyTranslationCalls, equals(1));
    });

    test('handlePanZoomStart calls startPanZoomGesture', () {
      final event = PointerPanZoomStartEvent();
      handler.handlePanZoomStart(event);
      expect(mockController.startPanZoomGestureCalls, equals(1));
    });

    test('handlePanZoomEnd calls endPanZoomGesture', () {
      final event = PointerPanZoomEndEvent();
      handler.handlePanZoomEnd(event);
      expect(mockController.endPanZoomGestureCalls, equals(1));
    });

    test('handlePanZoomUpdate without ctrl pinches or translates', () {
      final eventPinch = PointerPanZoomUpdateEvent(scale: 2);
      handler.handlePanZoomUpdate(eventPinch);
      expect(mockController.updatePinchGestureCalls, equals(1));
      
      mockController._mockCurrentScale = 2.0;
      final eventTranslate = PointerPanZoomUpdateEvent(panDelta: const Offset(10, 10));
      handler.handlePanZoomUpdate(eventTranslate);
      expect(mockController.applyTranslationCalls, equals(1));
    });
  });
}
