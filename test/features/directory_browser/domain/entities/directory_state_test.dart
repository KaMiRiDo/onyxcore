import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/directory_state.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  group('DirectoryState', () {
    final tItem = FileItem(
      path: '/home/test.txt',
      name: 'test.txt',
      type: FileItemType.document,
      modified: DateTime(2023),
    );

    test('should use correct defaults', () {
      final state = DirectoryState(currentPath: '/home');
      
      expect(state.currentPath, '/home');
      expect(state.items, isEmpty);
      expect(state.totalSizeBytes, 0);
      expect(state.isLoading, true);
      expect(state.error, isNull);
    });

    test('supports value equality (Equatable)', () {
      final state1 = DirectoryState(
        currentPath: '/home',
        items: [tItem],
        totalSizeBytes: 1024,
        isLoading: false,
        error: 'err',
      );
      final state2 = DirectoryState(
        currentPath: '/home',
        items: [tItem],
        totalSizeBytes: 1024,
        isLoading: false,
        error: 'err',
      );
      final state3 = DirectoryState(
        currentPath: '/home',
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('copyWith should update fields correctly', () {
      final state = DirectoryState(currentPath: '/home');
      
      final updated = state.copyWith(
        currentPath: '/opt',
        items: [tItem],
        totalSizeBytes: 200,
        isLoading: false,
        error: 'new error',
      );

      expect(updated.currentPath, '/opt');
      expect(updated.items, [tItem]);
      expect(updated.totalSizeBytes, 200);
      expect(updated.isLoading, false);
      expect(updated.error, 'new error');
    });

    test('copyWith should retain old values if null is passed, except error which clears if not passed', () {
      final state = DirectoryState(
        currentPath: '/home',
        items: [tItem],
        totalSizeBytes: 200,
        isLoading: false,
        error: 'err',
      );
      
      final updated = state.copyWith();

      expect(updated.currentPath, '/home');
      expect(updated.items, [tItem]);
      expect(updated.totalSizeBytes, 200);
      expect(updated.isLoading, false);
      expect(updated.error, isNull);
    });
  });
}
