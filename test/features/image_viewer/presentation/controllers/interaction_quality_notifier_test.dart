
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/interaction_quality_notifier.dart';

void main() {
  group('InteractionQualityNotifier', () {
    late InteractionQualityNotifier notifier;

    setUp(() {
      notifier = InteractionQualityNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state is inactive', () {
      expect(notifier.isActive, isFalse);
    });

    test('onInteractionStart sets active and notifies', () {
      var notifyCount = 0;
      notifier
        ..addListener(() => notifyCount++)
        ..onInteractionStart();
      
      expect(notifier.isActive, isTrue);
      expect(notifyCount, 1);
    });

    testWidgets('onInteractionEnd triggers settle timer and stays active until timer fires', (tester) async {
      var notifyCount = 0;
      notifier
        ..addListener(() => notifyCount++)
        ..onInteractionStart();
      expect(notifier.isActive, isTrue);
      expect(notifyCount, 1);

      notifier.onInteractionEnd();
      
      // Should still be active immediately after end, no new notification
      expect(notifier.isActive, isTrue);
      expect(notifyCount, 1);

      // Fast forward past settle delay (200ms)
      await tester.pump(const Duration(milliseconds: 250));
      
      // Now it should be inactive and notified
      expect(notifier.isActive, isFalse);
      expect(notifyCount, 2);
    });

    testWidgets('onInteractionStart during settle cancels timer', (tester) async {
      var notifyCount = 0;
      notifier
        ..addListener(() => notifyCount++)
        ..onInteractionStart() // notify 1
        ..onInteractionEnd();
      
      // Start another interaction before settle fires (e.g. 100ms in)
      await tester.pump(const Duration(milliseconds: 100));
      notifier.onInteractionStart(); // should cancel timer
      
      // Fast forward past original settle delay
      await tester.pump(const Duration(milliseconds: 150));
      
      // Should still be active, timer was cancelled
      expect(notifier.isActive, isTrue);
      expect(notifyCount, 1);
    });


    
    testWidgets('no post-dispose notification', (tester) async {
      final localNotifier = InteractionQualityNotifier();
      var notifyCount = 0;
      localNotifier
        ..addListener(() => notifyCount++)
        ..onInteractionStart()
        ..onInteractionEnd()
        ..dispose();
      
      // pump out the timer
      await tester.pump(const Duration(milliseconds: 250));
      
      // It would throw if it notified after dispose, but also check count
      expect(notifyCount, 1);
    });
  });
}
