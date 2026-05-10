import 'package:equatable/equatable.dart';

class VideoMarker extends Equatable {
  final String id;
  final Duration timestamp;
  final String content;

  const VideoMarker({
    required this.id,
    required this.timestamp,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.inMilliseconds,
      'content': content,
    };
  }

  factory VideoMarker.fromJson(Map<String, dynamic> json) {
    return VideoMarker(
      id: json['id'] as String,
      timestamp: Duration(milliseconds: json['timestamp'] as int),
      content: json['content'] as String,
    );
  }

  VideoMarker copyWith({
    String? id,
    Duration? timestamp,
    String? content,
  }) {
    return VideoMarker(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
    );
  }

  @override
  List<Object?> get props => [id, timestamp, content];
}
