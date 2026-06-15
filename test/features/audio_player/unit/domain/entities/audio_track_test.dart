
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

  group('AudioTrack Entity', () {
    // ── U-AUD-TRACK-01 ──
    test('creates an AudioTrack with all required fields', () {
      const track = AudioTrack(
        title: 'Test Song',
        artist: 'Test Artist',
        path: '/music/test.mp3',
      );

      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
      expect(track.path, '/music/test.mp3');
    });

    // ── U-AUD-TRACK-02 ──
    test('creates an AudioTrack with optional fields', () {
      const track = AudioTrack(
        title: 'Full Song',
        artist: 'Full Artist',
        path: '/music/full.mp3',
        albumArtPath: '/covers/full.jpg',
        duration: Duration(minutes: 3, seconds: 45),
      );

      expect(track.title, 'Full Song');
      expect(track.artist, 'Full Artist');
      expect(track.path, '/music/full.mp3');
      expect(track.albumArtPath, '/covers/full.jpg');
      expect(track.duration, const Duration(minutes: 3, seconds: 45));
    });

    // ── U-AUD-TRACK-03 ──
    test('creates an AudioTrack with null optional fields', () {
      const track = AudioTrack(
        title: 'Minimal',
        artist: 'Artist',
        path: '/music/min.mp3',
      );

      expect(track.albumArtPath, isNull);
      expect(track.duration, isNull);
    });

    // ── U-AUD-TRACK-04 ──
    test('considers two AudioTracks with same fields as equal', () {
      const trackA = AudioTrack(
        title: 'Same',
        artist: 'Same Artist',
        path: '/music/same.mp3',
        albumArtPath: '/art/same.jpg',
        duration: Duration(seconds: 200),
      );
      const trackB = AudioTrack(
        title: 'Same',
        artist: 'Same Artist',
        path: '/music/same.mp3',
        albumArtPath: '/art/same.jpg',
        duration: Duration(seconds: 200),
      );

      expect(trackA, equals(trackB));
    });

    // ── U-AUD-TRACK-05 ──
    test('considers two AudioTracks with different titles as not equal', () {
      const trackA = AudioTrack(
        title: 'Song A',
        artist: 'Artist',
        path: '/music/file.mp3',
      );
      const trackB = AudioTrack(
        title: 'Song B',
        artist: 'Artist',
        path: '/music/file.mp3',
      );

      expect(trackA, isNot(equals(trackB)));
    });

    // ── U-AUD-TRACK-06 ──
    test('considers two AudioTracks with different paths as not equal', () {
      const trackA = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/music/a.mp3',
      );
      const trackB = AudioTrack(
        title: 'Song',
        artist: 'Artist',
        path: '/music/b.mp3',
      );

      expect(trackA, isNot(equals(trackB)));
    });

    // ── U-AUD-TRACK-07 ──
    test(
      'considers two AudioTracks with different optional fields as not equal',
      () {
        const trackA = AudioTrack(
          title: 'Song',
          artist: 'Artist',
          path: '/music/file.mp3',
          duration: Duration(seconds: 120),
        );
        const trackB = AudioTrack(
          title: 'Song',
          artist: 'Artist',
          path: '/music/file.mp3',
        );

        expect(trackA, isNot(equals(trackB)));
      },
    );

    // ── U-AUD-TRACK-08 ──
    test('produces identical hashCodes for equal AudioTracks', () {
      const trackA = AudioTrack(
        title: 'Hash',
        artist: 'Artist',
        path: '/music/hash.mp3',
        albumArtPath: '/art/hash.jpg',
        duration: Duration(seconds: 60),
      );
      const trackB = AudioTrack(
        title: 'Hash',
        artist: 'Artist',
        path: '/music/hash.mp3',
        albumArtPath: '/art/hash.jpg',
        duration: Duration(seconds: 60),
      );

      expect(trackA.hashCode, equals(trackB.hashCode));
    });

    // ── U-AUD-TRACK-09 ──
    test('includes all 5 fields in props list', () {
      const track = AudioTrack(
        title: 'Props',
        artist: 'Artist',
        path: '/music/props.mp3',
        albumArtPath: '/art/props.jpg',
        duration: Duration(seconds: 30),
      );

      expect(track.props, hasLength(5));
      expect(
        track.props,
        equals([
          'Props',
          'Artist',
          '/music/props.mp3',
          '/art/props.jpg',
          const Duration(seconds: 30),
        ]),
      );
    });
  });
}
