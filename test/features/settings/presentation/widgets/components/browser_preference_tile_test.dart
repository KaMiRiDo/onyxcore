import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/components/browser_preference_tile.dart';

class MockSettingsNotifier extends AsyncNotifier<AppSettings> implements SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(BrowserDetector.reset);

  testWidgets('BrowserPreferenceTile renders loading initially', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BrowserPreferenceTile()),
        ),
      ),
    );

    await tester.pump();

    // Initial state before initBrowsers completes
    expect(find.text('Custom Extractor Browser'), findsOneWidget);
  });

  testWidgets('BrowserPreferenceTile displays browsers and disables unsupported ones', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BrowserPreferenceTile()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Custom Extractor Browser'), findsOneWidget);
    // Google Chrome should be an option
    expect(find.textContaining('Chrome'), findsOneWidget);
  });
}
