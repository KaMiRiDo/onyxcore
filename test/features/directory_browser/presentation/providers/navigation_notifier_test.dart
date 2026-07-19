// ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings();
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });
  group('NavigationNotifier', () {
    late ProviderContainer container;

    // Use a stable path that is guaranteed to exist on Linux and
    // does NOT start with '/mnt' so handleEject can return it as fallback.
    const initialPath = '/home';

    setUp(() async {
      final mockSettings = MockSettingsRepository();

      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
      );
      // Initialize tab manager with a default tab to avoid StateError
      // Wait a few milliseconds to ensure the new tab gets a unique ID 
      // based on DateTime.now().millisecondsSinceEpoch
      await Future<void>.delayed(const Duration(milliseconds: 5));
      container.read(tabManagerProvider.notifier).addTab(path: initialPath);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state pulls from tab manager', () {
      final state = container.read(navigationProvider);
      expect(state.history, [initialPath]);
      expect(state.historyIndex, 0);
    });

    test('initialize is a no-op', () {
      final notifier = container.read(navigationProvider.notifier);
      notifier.initialize('/new/path');
      
      final state = container.read(navigationProvider);
      expect(state.history, [initialPath]);
      expect(state.historyIndex, 0);
    });

    test('navigateTo updates tab manager path and history', () {
      final notifier = container.read(navigationProvider.notifier);
      notifier.navigateTo('/new/path');
      
      final state = container.read(navigationProvider);
      expect(state.history, [initialPath, '/new/path']);
      expect(state.historyIndex, 1);
    });

    test('goBack and goForward update history correctly', () {
      final notifier = container.read(navigationProvider.notifier);
      notifier.navigateTo('/path/1');
      notifier.navigateTo('/path/2');

      var state = container.read(navigationProvider);
      expect(state.historyIndex, 2);

      notifier.goBack();
      state = container.read(navigationProvider);
      expect(state.historyIndex, 1);

      notifier.goForward();
      state = container.read(navigationProvider);
      expect(state.historyIndex, 2);
    });

    test('handleEject returns previous valid path', () {
      final notifier = container.read(navigationProvider.notifier);
      notifier.navigateTo('/mnt/usb1/folder1');
      notifier.navigateTo('/mnt/usb1/folder2');

      final result = notifier.handleEject('/mnt/usb1');
      
      expect(result, initialPath);
      
      final stateAfter = container.read(navigationProvider);
      expect(stateAfter.history.last, initialPath);
    });

    test('handleEject returns null if no valid previous path', () {
      final notifier = container.read(navigationProvider.notifier);
      // Eject a path that covers all history entries → no valid fallback
      final result = notifier.handleEject('/home');
      expect(result, isNull);
    });
  });
}
