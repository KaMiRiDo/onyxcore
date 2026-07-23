import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart';
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
  testWidgets('SettingsDialog shows openInStandaloneMode toggle', (tester) async {
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
            body: SettingsDialog(initialTab: 1, initialSection: 'General'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open in standalone mode'), findsOneWidget);
    expect(find.byType(OnyxSwitch), findsWidgets);
  });
}
