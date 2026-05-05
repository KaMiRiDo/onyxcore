import 'package:equatable/equatable.dart';

class AudioTrack extends Equatable {
  final String title;
  final String artist;
  final String path;
  final String? albumArtPath;
  final Duration? duration;

  const AudioTrack({
    required this.title,
    required this.artist,
    required this.path,
    this.albumArtPath,
    this.duration,
  });

  @override
  List<Object?> get props => [title, artist, path, albumArtPath, duration];
}
