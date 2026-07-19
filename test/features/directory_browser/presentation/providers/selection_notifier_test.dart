// ignore_for_file: cascade_invocations
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
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
  group('SelectionNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      final mockSettings = MockSettingsRepository();

      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
      );
      container.read(tabManagerProvider.notifier).addTab(path: '/initial');
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(selectionProvider);
      expect(state.selectedPaths, isEmpty);
      expect(state.isSelectionMode, isFalse);
    });

    test('select adds item to selection', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.select('item1');
      expect(container.read(selectionProvider).selectedPaths, contains('item1'));
      expect(container.read(selectionProvider).isSelectionMode, isTrue);
    });

    test('deselect removes item from selection', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.select('item1');
      notifier.deselect(['item1']);
      expect(container.read(selectionProvider).selectedPaths, isEmpty);
    });

    test('selectAll and deselectAll works correctly', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.selectAll(['item1', 'item2']);
      expect(container.read(selectionProvider).selectedPaths.length, 2);
      
      notifier.deselectAll();
      expect(container.read(selectionProvider).selectedPaths, isEmpty);
    });

    test('selectMultiple adds items', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.selectMultiple(['item1', 'item2']);
      expect(container.read(selectionProvider).selectedPaths.length, 2);
      
      notifier.selectMultiple(['item3'], isCtrl: true);
      expect(container.read(selectionProvider).selectedPaths.length, 3);
    });

    test('onItemTap without modifiers selects single item', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.onItemTap(
        currentIndex: 0, 
        allPaths: ['item1', 'item2'], 
        isShift: false, 
        isCtrl: false
      );
      
      expect(container.read(selectionProvider).selectedPaths, contains('item1'));
      expect(container.read(selectionProvider).selectedPaths.length, 1);
    });

    test('onItemTap with Ctrl toggles item', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.onItemTap(
        currentIndex: 0, 
        allPaths: ['item1', 'item2'], 
        isShift: false, 
        isCtrl: true
      );
      expect(container.read(selectionProvider).selectedPaths, contains('item1'));
      
      notifier.onItemTap(
        currentIndex: 0, 
        allPaths: ['item1', 'item2'], 
        isShift: false, 
        isCtrl: true
      );
      expect(container.read(selectionProvider).selectedPaths, isEmpty);
    });

    test('onItemTap with Shift selects range', () {
      final notifier = container.read(selectionProvider.notifier);
      
      notifier.onItemTap(
        currentIndex: 0, 
        allPaths: ['item1', 'item2', 'item3'], 
        isShift: false, 
        isCtrl: false
      );
      
      notifier.onItemTap(
        currentIndex: 2, 
        allPaths: ['item1', 'item2', 'item3'], 
        isShift: true, 
        isCtrl: false
      );
      
      final selected = container.read(selectionProvider).selectedPaths;
      expect(selected.length, 3);
      expect(selected, containsAll(['item1', 'item2', 'item3']));
    });
  });
}
