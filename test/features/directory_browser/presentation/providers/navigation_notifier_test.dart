import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings(globalSortOption: SortOption.aToZ);
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });
  group('NavigationNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      final mockSettings = MockSettingsRepository();
      when(() => mockSettings.getFolderSort(any(), any())).thenReturn(SortOption.aToZ);
      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
      );
      // Initialize tab manager with a default tab to avoid StateError
      // Wait a few milliseconds to ensure the new tab gets a unique ID 
      // based on DateTime.now().millisecondsSinceEpoch
      await Future.delayed(const Duration(milliseconds: 5));
      container.read(tabManagerProvider.notifier).addTab(path: '/initial');
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state pulls from tab manager', () {
      final state = container.read(navigationProvider);
      expect(state.history, ['/initial']);
      expect(state.historyIndex, 0);
    });

    test('initialize is a no-op', () {
      final notifier = container.read(navigationProvider.notifier);
      notifier.initialize('/new/path');
      
      final state = container.read(navigationProvider);
      expect(state.history, ['/initial']);
      expect(state.historyIndex, 0);
    });

    test('navigateTo updates tab manager path and history', () {
      final notifier = container.read(navigationProvider.notifier);
      notifier.navigateTo('/new/path');
      
      final state = container.read(navigationProvider);
      expect(state.history, ['/initial', '/new/path']);
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
      
      expect(result, '/initial');
      
      final state = container.read(navigationProvider);
      expect(state.history.last, '/initial');
    });

    test('handleEject returns null if no valid previous path', () {
      final notifier = container.read(navigationProvider.notifier);
      final result = notifier.handleEject('/initial');
      expect(result, isNull);
    });
  });
}
