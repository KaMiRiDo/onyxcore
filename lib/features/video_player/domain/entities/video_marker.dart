import 'package:equatable/equatable.dart';

class VideoMarker extends Equatable {
  const VideoMarker({
    required this.id,
    required this.timestamp,
    required this.content,
    this.icon = '📍',
  });

  factory VideoMarker.fromJson(Map<String, dynamic> json) {
    return VideoMarker(
      id: json['id'] as String,
      timestamp: Duration(milliseconds: json['timestamp'] as int),
      content: json['content'] as String,
      icon: (json['icon'] as String?) ?? '📍',
    );
  }
  final String id;
  final Duration timestamp;
  final String content;
  final String icon;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.inMilliseconds,
      'content': content,
      'icon': icon,
    };
  }

  VideoMarker copyWith({
    String? id,
    Duration? timestamp,
    String? content,
    String? icon,
  }) {
    return VideoMarker(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      content: content ?? this.content,
      icon: icon ?? this.icon,
    );
  }

  @override
  List<Object?> get props => [id, timestamp, content, icon];
}
