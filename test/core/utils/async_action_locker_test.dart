import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/async_action_locker.dart';

void main() {
  group('AsyncActionLocker Tests', () {
    test('execute runs the action and locks/unlocks', () async {
      final locker = AsyncActionLocker();
      var actionRan = false;
      var lockChanges = 0;

      await locker.execute(() async {
        actionRan = true;
        expect(locker.isLocked, isTrue);
      }, onLockStateChanged: () => lockChanges++);

      expect(actionRan, isTrue);
      expect(locker.isLocked, isFalse);
      expect(lockChanges, 2);
    });

    test('execute prevents concurrent runs', () async {
      final locker = AsyncActionLocker();
      var runCount = 0;

      Future<void> slowAction() async {
        runCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Start the action but don't await immediately
      final future1 = locker.execute(slowAction);
      
      // Attempt to start it again while the first is running
      final future2 = locker.execute(slowAction);

      await future1;
      await future2;

      // It should have only run once!
      expect(runCount, 1);
    });
  });
}
