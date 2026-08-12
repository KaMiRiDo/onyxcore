import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';

class FakeSettingsNotifier extends AsyncNotifier<AppSettings> implements SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings();
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('SettingsDialog build performance test', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SettingsDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final stopwatch = Stopwatch()..start();
    
    // Rebuild the dialog 100 times
    for (var i = 0; i < 100; i++) {
      tester.binding.scheduleFrame();
      await tester.pump();
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    
    // The build time for 100 frames should be extremely fast (e.g. < 100ms total in a test environment)
    // If it's hitting the disk synchronously every frame, it will be much slower.
    debugPrint('SettingsDialog 100 frames build time: ${elapsed}ms');
    expect(elapsed, lessThan(250), reason: 'SettingsDialog is taking too long to build. Likely synchronous IO on main thread.');
  });
}
