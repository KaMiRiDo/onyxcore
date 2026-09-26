import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_segment.dart';

class VideoEditorState extends Equatable {
  const VideoEditorState({
    this.isEditing = false,
    this.segments = const [],
    this.pendingSegmentStart,
  });

  final bool isEditing;
  final List<VideoSegment> segments;
  final Duration? pendingSegmentStart;

  VideoEditorState copyWith({
    bool? isEditing,
    List<VideoSegment>? segments,
    Duration? pendingSegmentStart,
    bool clearPendingSegmentStart = false,
  }) {
    return VideoEditorState(
      isEditing: isEditing ?? this.isEditing,
      segments: segments ?? this.segments,
      pendingSegmentStart: clearPendingSegmentStart
          ? null
          : (pendingSegmentStart ?? this.pendingSegmentStart),
    );
  }

  @override
  List<Object?> get props => [isEditing, segments, pendingSegmentStart];
}

class VideoEditorNotifier extends Notifier<VideoEditorState> {
  @override
  VideoEditorState build() {
    return const VideoEditorState();
  }

  void startEdit() {
    state = state.copyWith(isEditing: true);
  }

  void stopEdit() {
    state = const VideoEditorState();
  }

  void markTimestamp(Duration timestamp, Duration videoDuration) {
    if (state.pendingSegmentStart == null) {
      // Start marking a new segment
      state = state.copyWith(pendingSegmentStart: timestamp);
      // Auto-create a temporary segment spanning to the end of the video
      final newSegment = VideoSegment.create(
        start: timestamp,
        end: videoDuration,
      );
      state = state.copyWith(segments: [...state.segments, newSegment]);
    } else {
      // Finalize the segment end time
      final start = state.pendingSegmentStart!;
      
      if (timestamp <= start) {
        // Ignore invalid end time
        return;
      }

      // Update the temporary segment we created
      final updatedSegments = state.segments.map((seg) {
        if (seg.start == start && seg.end == videoDuration) {
          return seg.copyWith(end: timestamp);
        }
        return seg;
      }).toList();

      state = state.copyWith(
        segments: updatedSegments,
        clearPendingSegmentStart: true,
      );
    }
  }

  void deleteSegment(String id) {
    state = state.copyWith(
      segments: state.segments.where((seg) => seg.id != id).toList(),
    );
  }

  void toggleMute(String id) {
    state = state.copyWith(
      segments: state.segments.map((seg) {
        if (seg.id == id) {
          return seg.copyWith(isMuted: !seg.isMuted);
        }
        return seg;
      }).toList(),
    );
  }

  void updateSegment(String id, VideoSegment newSegment) {
    state = state.copyWith(
      segments: state.segments.map((seg) {
        if (seg.id == id) {
          return newSegment;
        }
        return seg;
      }).toList(),
    );
  }
}

final videoEditorProvider =
    NotifierProvider<VideoEditorNotifier, VideoEditorState>(
  VideoEditorNotifier.new,
);
