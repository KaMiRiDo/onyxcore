import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class VideoSegment extends Equatable {
  const VideoSegment({
    required this.id,
    required this.start,
    required this.end,
    this.isMuted = false,
    this.speed = 1.0,
  });

  factory VideoSegment.create({
    required Duration start,
    required Duration end,
  }) {
    return VideoSegment(
      id: const Uuid().v4(),
      start: start,
      end: end,
    );
  }

  final String id;
  final Duration start;
  final Duration end;
  final bool isMuted;
  final double speed;

  VideoSegment copyWith({
    String? id,
    Duration? start,
    Duration? end,
    bool? isMuted,
    double? speed,
  }) {
    return VideoSegment(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      isMuted: isMuted ?? this.isMuted,
      speed: speed ?? this.speed,
    );
  }

  @override
  List<Object?> get props => [id, start, end, isMuted, speed];
}
