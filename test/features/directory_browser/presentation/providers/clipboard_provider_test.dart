// ignore_for_file: cascade_invocations
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';

void main() {
  group('ClipboardState', () {
    test('default constructor uses FileOperationType.none and empty paths', () {
      const state = ClipboardState();
      expect(state.type, FileOperationType.none);
      expect(state.paths, isEmpty);
      expect(state.isCopy, isFalse);
      expect(state.isCut, isFalse);
    });

    test('isCopy and isCut work correctly', () {
      const copyState = ClipboardState(type: FileOperationType.copy);
      expect(copyState.isCopy, isTrue);
      expect(copyState.isCut, isFalse);

      const cutState = ClipboardState(type: FileOperationType.cut);
      expect(cutState.isCopy, isFalse);
      expect(cutState.isCut, isTrue);
    });

    test('copyWith updates fields correctly', () {
      const state = ClipboardState();
      final updatedState = state.copyWith(
        type: FileOperationType.copy,
        paths: ['/test1', '/test2'],
      );

      expect(updatedState.type, FileOperationType.copy);
      expect(updatedState.paths, ['/test1', '/test2']);
    });

    test('copyWith retains old values if null is passed', () {
      const state = ClipboardState(
        type: FileOperationType.cut,
        paths: ['/test'],
      );
      final updatedState = state.copyWith();

      expect(updatedState.type, FileOperationType.cut);
      expect(updatedState.paths, ['/test']);
    });
  });

  group('ClipboardNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () {
      final state = container.read(clipboardProvider);
      expect(state.type, FileOperationType.none);
      expect(state.paths, isEmpty);
    });

    test('copy updates state with type copy and paths', () {
      final notifier = container.read(clipboardProvider.notifier);
      notifier.copy(['/test/path']);

      final state = container.read(clipboardProvider);
      expect(state.type, FileOperationType.copy);
      expect(state.paths, ['/test/path']);
    });

    test('cut updates state with type cut and paths', () {
      final notifier = container.read(clipboardProvider.notifier);
      notifier.cut(['/test/path2']);

      final state = container.read(clipboardProvider);
      expect(state.type, FileOperationType.cut);
      expect(state.paths, ['/test/path2']);
    });

    test('clear resets state to default', () {
      final notifier = container.read(clipboardProvider.notifier);
      notifier.copy(['/test/path']);
      notifier.clear();

      final state = container.read(clipboardProvider);
      expect(state.type, FileOperationType.none);
      expect(state.paths, isEmpty);
    });
  });
}
