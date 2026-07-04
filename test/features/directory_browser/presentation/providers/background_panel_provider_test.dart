import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';

void main() {
  group('Background Panel Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('backgroundPanelOpenProvider initial state is false', () {
      final state = container.read(backgroundPanelOpenProvider);
      expect(state, isFalse);
    });

    test('backgroundPanelOpenProvider updates state', () {
      container.read(backgroundPanelOpenProvider.notifier).state = true;
      expect(container.read(backgroundPanelOpenProvider), isTrue);
    });

    test('backgroundPanelViewProvider initial state is BackgroundPanelView.tasks', () {
      final state = container.read(backgroundPanelViewProvider);
      expect(state, BackgroundPanelView.tasks);
    });

    test('backgroundPanelViewProvider updates state', () {
      container.read(backgroundPanelViewProvider.notifier).state = BackgroundPanelView.history;
      expect(container.read(backgroundPanelViewProvider), BackgroundPanelView.history);
    });

    test('selectedHistoryIdProvider initial state is null', () {
      final state = container.read(selectedHistoryIdProvider);
      expect(state, isNull);
    });

    test('selectedHistoryIdProvider updates state', () {
      container.read(selectedHistoryIdProvider.notifier).state = 'task123';
      expect(container.read(selectedHistoryIdProvider), 'task123');
    });

    test('backgroundPanelWidthFractionProvider initial state is 0.25', () {
      final state = container.read(backgroundPanelWidthFractionProvider);
      expect(state, 0.25);
    });

    test('backgroundPanelWidthFractionProvider updates state', () {
      container.read(backgroundPanelWidthFractionProvider.notifier).state = 0.5;
      expect(container.read(backgroundPanelWidthFractionProvider), 0.5);
    });

    test('isBackgroundPanelDraggingProvider initial state is false', () {
      final state = container.read(isBackgroundPanelDraggingProvider);
      expect(state, isFalse);
    });

    test('isBackgroundPanelDraggingProvider updates state', () {
      container.read(isBackgroundPanelDraggingProvider.notifier).state = true;
      expect(container.read(isBackgroundPanelDraggingProvider), isTrue);
    });
  });
}
