import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_editor_provider.dart';

void main() {
  group('VideoEditorProvider', () {
    late ProviderContainer container;
    const videoDuration = Duration(minutes: 10);

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () {
      final state = container.read(videoEditorProvider);
      expect(state.isEditing, false);
      expect(state.segments, isEmpty);
      expect(state.pendingSegmentStart, isNull);
    });

    test('startEdit sets isEditing to true', () {
      final notifier = container.read(videoEditorProvider.notifier);
      notifier.startEdit();
      final state = container.read(videoEditorProvider);
      expect(state.isEditing, true);
    });

    test('stopEdit resets state', () {
      final notifier = container.read(videoEditorProvider.notifier);
      notifier.startEdit();
      notifier.stopEdit();
      final state = container.read(videoEditorProvider);
      expect(state.isEditing, false);
    });

    test('markTimestamp sets pending start if none exists', () {
      final notifier = container.read(videoEditorProvider.notifier);
      const timestamp = Duration(seconds: 10);
      notifier.markTimestamp(timestamp, videoDuration);

      final state = container.read(videoEditorProvider);
      expect(state.pendingSegmentStart, timestamp);
      expect(state.segments.length, 1);
      expect(state.segments.first.start, timestamp);
      expect(state.segments.first.end, videoDuration); // Auto-span to end
    });

    test('markTimestamp finalizes segment if pending start exists', () {
      final notifier = container.read(videoEditorProvider.notifier);
      const start = Duration(seconds: 10);
      const end = Duration(seconds: 20);

      notifier.markTimestamp(start, videoDuration);
      notifier.markTimestamp(end, videoDuration);

      final state = container.read(videoEditorProvider);
      expect(state.pendingSegmentStart, isNull);
      expect(state.segments.length, 1);
      expect(state.segments.first.start, start);
      expect(state.segments.first.end, end);
    });

    test('markTimestamp ignores if end is before start', () {
      final notifier = container.read(videoEditorProvider.notifier);
      const start = Duration(seconds: 20);
      const invalidEnd = Duration(seconds: 10);

      notifier.markTimestamp(start, videoDuration);
      notifier.markTimestamp(invalidEnd, videoDuration);

      final state = container.read(videoEditorProvider);
      // Should remain pending or reset? We'll assert it ignores and keeps pending
      expect(state.pendingSegmentStart, start);
    });

    test('deleteSegment removes segment by id', () {
      final notifier = container.read(videoEditorProvider.notifier);
      notifier.markTimestamp(const Duration(seconds: 10), videoDuration);
      notifier.markTimestamp(const Duration(seconds: 20), videoDuration);

      var state = container.read(videoEditorProvider);
      final segmentId = state.segments.first.id;

      notifier.deleteSegment(segmentId);

      state = container.read(videoEditorProvider);
      expect(state.segments, isEmpty);
    });
  });
}
