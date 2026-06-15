
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/audio_player/domain/entities/audio_track.dart';

void main() {
  setUpAll(() {
    try {
      import_hive.Hive.init(import_io.Directory.systemTemp.path);
    } catch (_) {}
  });

  group('AudioTrack', () {
    test('create an AudioTrack with all required fields (U-AUD-TRACK-01)', () {
      const track = AudioTrack(
        title: 'Song Title',
        artist: 'Artist Name',
        path: '/path/to/song.mp3',
      );

      expect(track.title, 'Song Title');
      expect(track.artist, 'Artist Name');
      expect(track.path, '/path/to/song.mp3');
      expect(track.albumArtPath, isNull);
      expect(track.duration, isNull);
    });

    test('create an AudioTrack with optional fields (U-AUD-TRACK-02)', () {
      const duration = Duration(seconds: 120);
      const track = AudioTrack(
        title: 'Song Title',
        artist: 'Artist Name',
        path: '/path/to/song.mp3',
        albumArtPath: '/path/to/art.jpg',
        duration: duration,
      );

      expect(track.title, 'Song Title');
      expect(track.artist, 'Artist Name');
      expect(track.path, '/path/to/song.mp3');
      expect(track.albumArtPath, '/path/to/art.jpg');
      expect(track.duration, duration);
    });

    test('create an AudioTrack with null optional fields (U-AUD-TRACK-03)', () {
      const track = AudioTrack(
        title: 'Song Title',
        artist: 'Artist Name',
        path: '/path/to/song.mp3',
        albumArtPath: null,
        duration: null,
      );

      expect(track.albumArtPath, isNull);
      expect(track.duration, isNull);
    });

    test('consider two AudioTracks with same fields as equal (U-AUD-TRACK-04)', () {
      const track1 = AudioTrack(
        title: 'Song Title',
        artist: 'Artist Name',
        path: '/path/to/song.mp3',
        albumArtPath: '/path/to/art.jpg',
        duration: Duration(seconds: 120),
      );

      const track2 = AudioTrack(
        title: 'Song Title',
        artist: 'Artist Name',
        path: '/path/to/song.mp3',
        albumArtPath: '/path/to/art.jpg',
        duration: Duration(seconds: 120),
      );

      expect(track1, equals(track2));
      expect(track1 == track2, isTrue);
    });

    test('consider two AudioTracks with different titles as not equal (U-AUD-TRACK-05)', () {
      const track1 = AudioTrack(title: 'Song 1', artist: 'Artist', path: '/path');
      const track2 = AudioTrack(title: 'Song 2', artist: 'Artist', path: '/path');

      expect(track1, isNot(equals(track2)));
    });

    test('consider two AudioTracks with different paths as not equal (U-AUD-TRACK-06)', () {
      const track1 = AudioTrack(title: 'Song', artist: 'Artist', path: '/path1');
      const track2 = AudioTrack(title: 'Song', artist: 'Artist', path: '/path2');

      expect(track1, isNot(equals(track2)));
    });

    test('consider two AudioTracks with different optional fields as not equal (U-AUD-TRACK-07)', () {
      const track1 = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/path',
        duration: Duration(seconds: 120),
      );
      const track2 = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/path',
        duration: null,
      );

      expect(track1, isNot(equals(track2)));
    });

    test('produce identical hashCodes for equal AudioTracks (U-AUD-TRACK-08)', () {
      const track1 = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/path',
        albumArtPath: '/art',
        duration: Duration(seconds: 120),
      );
      const track2 = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/path',
        albumArtPath: '/art',
        duration: Duration(seconds: 120),
      );

      expect(track1.hashCode, equals(track2.hashCode));
    });

    test('include all 5 fields in props list (U-AUD-TRACK-09)', () {
      const track = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/path',
        albumArtPath: '/art',
        duration: Duration(seconds: 120),
      );

      expect(
        track.props,
        equals(['Song', 'Artist', '/path', '/art', const Duration(seconds: 120)]),
      );
    });
  });
}
