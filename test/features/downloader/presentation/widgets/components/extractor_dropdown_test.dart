import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/extractor_dropdown.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockSettingsNotifier extends SettingsNotifier {
  MockSettingsNotifier(this._settings);
  final AppSettings _settings;

  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  testWidgets('ExtractorDropdown renders correctly when enabled', (WidgetTester tester) async {
    const settings = AppSettings(customExtractorsEnabled: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier(settings)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ExtractorDropdown()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No Extractor'), findsWidgets);
    
    // The dropdown should be enabled
    final dropdown = tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
    expect(dropdown.enabled, isTrue);
  });

  testWidgets('ExtractorDropdown is disabled when feature is off', (WidgetTester tester) async {
    const settings = AppSettings();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier(settings)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ExtractorDropdown()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No Extractor'), findsWidgets);
    
    // The dropdown should be disabled
    final dropdown = tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>));
    expect(dropdown.enabled, isFalse);
  });
}
