import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';

void main() {
  testWidgets('SettingsDialog build performance test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stopwatch = Stopwatch()..start();
    
    // Rebuild the dialog 100 times
    for (int i = 0; i < 100; i++) {
      tester.binding.scheduleFrame();
      await tester.pump();
    }
    
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    
    // The build time for 100 frames should be extremely fast (e.g. < 100ms total in a test environment)
    // If it's hitting the disk synchronously every frame, it will be much slower.
    print('SettingsDialog 100 frames build time: ${elapsed}ms');
    expect(elapsed, lessThan(100), reason: 'SettingsDialog is taking too long to build. Likely synchronous IO on main thread.');
  });
}
