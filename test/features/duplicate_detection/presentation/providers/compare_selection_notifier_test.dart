import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_selection_notifier.dart';

void main() {
  group('CompareSelectionNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty set', () {
      final state = container.read(compareSelectionProvider);
      expect(state, isEmpty);
    });

    test('select adds path to selection', () {
      final notifier = container.read(compareSelectionProvider.notifier)
        ..select('/path/to/source.jpg');

      final state = container.read(compareSelectionProvider);
      expect(state, contains('/path/to/source.jpg'));
      expect(notifier.isSelected('/path/to/source.jpg'), isTrue);
    });

    test('deselect removes path from selection', () {
      final notifier = container.read(compareSelectionProvider.notifier)
        ..select('/path/to/source.jpg')
        ..deselect('/path/to/source.jpg');

      final state = container.read(compareSelectionProvider);
      expect(state, isEmpty);
      expect(notifier.isSelected('/path/to/source.jpg'), isFalse);
    });

    test('toggle flips path selection state', () {
      final notifier = container.read(compareSelectionProvider.notifier)..toggle('/path/to/source.jpg');
      expect(container.read(compareSelectionProvider), contains('/path/to/source.jpg'));

      notifier.toggle('/path/to/source.jpg');
      expect(container.read(compareSelectionProvider), isEmpty);
    });

    test('selectAll selects all given paths', () {
      container
          .read(compareSelectionProvider.notifier)
          .selectAll(['/a.jpg', '/b.jpg', '/c.jpg']);

      final state = container.read(compareSelectionProvider);
      expect(state, containsAll(['/a.jpg', '/b.jpg', '/c.jpg']));
    });

    test('deselectAll clears all selections', () {
      container.read(compareSelectionProvider.notifier)
        ..selectAll(['/a.jpg', '/b.jpg'])
        ..deselectAll();

      expect(container.read(compareSelectionProvider), isEmpty);
    });

    test('isGroupSelected returns correct tristate value', () {
      final notifier = container.read(compareSelectionProvider.notifier);
      final group = ['/group/src.jpg', '/group/dest1.jpg', '/group/dest2.jpg'];

      // None selected -> false
      expect(notifier.isGroupSelected(group), isFalse);

      // Some selected -> null (indeterminate)
      notifier.select('/group/src.jpg');
      expect(notifier.isGroupSelected(group), isNull);

      // All selected -> true
      notifier.selectAll(group);
      expect(notifier.isGroupSelected(group), isTrue);
    });

    test('toggleGroup deselects all when group is fully selected', () {
      final group = ['/group/src.jpg', '/group/dest.jpg'];
      container.read(compareSelectionProvider.notifier)
        ..selectAll(group)
        ..toggleGroup(group);
      expect(container.read(compareSelectionProvider), isEmpty);
    });

    test('toggleGroup selects all when group is partially selected or unselected', () {
      final notifier = container.read(compareSelectionProvider.notifier);
      final group = ['/group/src.jpg', '/group/dest.jpg'];

      // Unselected -> select all
      notifier.toggleGroup(group);
      expect(container.read(compareSelectionProvider), containsAll(group));

      // Deselect one, making it partially selected, then toggle
      notifier
        ..deselect('/group/dest.jpg')
        ..toggleGroup(group);
      expect(container.read(compareSelectionProvider), containsAll(group));
    });

    test('removePaths removes subset of paths', () {
      container.read(compareSelectionProvider.notifier)
        ..selectAll(['/a.jpg', '/b.jpg', '/c.jpg'])
        ..removePaths(['/b.jpg', '/c.jpg']);

      expect(container.read(compareSelectionProvider), equals({'/a.jpg'}));
    });

    test('reset clears selection completely', () {
      container.read(compareSelectionProvider.notifier)
        ..selectAll(['/a.jpg', '/b.jpg'])
        ..reset();

      expect(container.read(compareSelectionProvider), isEmpty);
    });
  });
}
