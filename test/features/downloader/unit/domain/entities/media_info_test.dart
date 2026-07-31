// ignore_for_file: inference_failure_on_collection_literal
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

void main() {
  group('MediaFormat Entity Tests', () {
    // ═══════════════════════════════════════════════════════════════
    // 1. MediaFormat — JSON Parsing
    // ═══════════════════════════════════════════════════════════════
    group('MediaFormat — JSON Parsing', () {
      test('U-DL-FMT-01: parses standard format JSON correctly', () {
        final json = {
          'format_id': '137',
          'ext': 'mp4',
          'resolution': '1920x1080',
          'filesize': 10000,
          'format': '137 - 1080p',
          'vcodec': 'avc1',
          'acodec': 'mp4a',
          'format_note': '1080p',
          'url': 'https://example.com/video.mp4',
        };
        final format = MediaFormat.fromJson(json);

        expect(format.formatId, '137');
        expect(format.extension, 'mp4');
        expect(format.resolution, '1920x1080');
        expect(format.filesize, 10000);
        expect(format.formatString, '137 - 1080p');
        expect(format.videoCodec, 'avc1');
        expect(format.audioCodec, 'mp4a');
        expect(format.formatNote, '1080p');
        expect(format.url, 'https://example.com/video.mp4');
      });

      test('U-DL-FMT-02: constructs resolution from width and height if resolution missing', () {
        final json = {
          'format_id': '137',
          'ext': 'mp4',
          'width': 1920,
          'height': 1080,
          'format': '137',
        };
        final format = MediaFormat.fromJson(json);
        expect(format.resolution, '1920x1080');
      });

      test('U-DL-FMT-03: fallbacks to "audio only" if no resolution or dimensions exist', () {
        final json = {
          'format_id': '140',
          'ext': 'm4a',
          'format': '140',
        };
        final format = MediaFormat.fromJson(json);
        expect(format.resolution, 'audio only');
      });

      test('U-DL-FMT-04: parses filesize_approx if filesize is null', () {
        final json = {
          'format_id': '137',
          'ext': 'mp4',
          'filesize': null,
          'filesize_approx': 5000,
          'format': '137',
        };
        final format = MediaFormat.fromJson(json);
        expect(format.filesize, 5000);
      });

      test('U-DL-FMT-05: defaults empty strings for missing required fields', () {
        final format = MediaFormat.fromJson(const {});
        expect(format.formatId, '');
        expect(format.extension, '');
        expect(format.formatString, '');
      });

      test('U-DL-FMT-06: parses nullable codec fields', () {
        final json = {
          'vcodec': 'avc1',
          'acodec': 'mp4a',
        };
        final format = MediaFormat.fromJson(json);
        expect(format.videoCodec, 'avc1');
        expect(format.audioCodec, 'mp4a');
      });

      test('U-DL-FMT-07: handles format_id as integer in JSON', () {
        final json = {
          'format_id': 137,
        };
        final format = MediaFormat.fromJson(json);
        expect(format.formatId, '137');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 2. MediaFormat — JSON Serialization
    // ═══════════════════════════════════════════════════════════════
    group('MediaFormat — JSON Serialization', () {
      test('U-DL-FMT-08: serializes format object back to exact JSON structure', () {
        const format = MediaFormat(
          formatId: '137',
          extension: 'mp4',
          resolution: '1920x1080',
          videoCodec: 'avc1',
          audioCodec: 'mp4a',
          filesize: 10000,
          formatNote: '1080p',
          formatString: '137 - 1080p',
          url: 'https://example.com',
        );

        final json = format.toJson();
        expect(json['format_id'], '137');
        expect(json['ext'], 'mp4');
        expect(json['resolution'], '1920x1080');
        expect(json['vcodec'], 'avc1');
        expect(json['acodec'], 'mp4a');
        expect(json['filesize'], 10000);
        expect(json['format_note'], '1080p');
        expect(json['format'], '137 - 1080p');
        expect(json['url'], 'https://example.com');
      });

      test('U-DL-FMT-09: omits null fields in serialization', () {
        const format = MediaFormat(
          formatId: '137',
          extension: 'mp4',
          resolution: '1920x1080',
          formatString: '137 - 1080p',
        );

        final json = format.toJson();
        expect(json.containsKey('vcodec'), isFalse);
        expect(json.containsKey('acodec'), isFalse);
        expect(json.containsKey('filesize'), isFalse);
        expect(json.containsKey('format_note'), isFalse);
        expect(json.containsKey('url'), isFalse);
      });

      test('U-DL-FMT-10: supports round-trip serialization', () {
        const original = MediaFormat(
          formatId: '137',
          extension: 'mp4',
          resolution: '1920x1080',
          videoCodec: 'avc1',
          audioCodec: 'mp4a',
          filesize: 10000,
          formatNote: '1080p',
          formatString: '137 - 1080p',
          url: 'https://example.com',
        );

        final json = original.toJson();
        final result = MediaFormat.fromJson(json);
        expect(result.formatId, original.formatId);
        expect(result.extension, original.extension);
        expect(result.resolution, original.resolution);
        expect(result.videoCodec, original.videoCodec);
        expect(result.audioCodec, original.audioCodec);
        expect(result.filesize, original.filesize);
        expect(result.formatNote, original.formatNote);
        expect(result.formatString, original.formatString);
        expect(result.url, original.url);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 3. MediaFormat — Equality & HashCode
    // ═══════════════════════════════════════════════════════════════
    group('MediaFormat — Equality & HashCode', () {
      test('U-DL-FMT-11: considers formats equal if formatId and formatString match', () {
        const a = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: '1 - best', filesize: 100);
        const b = MediaFormat(formatId: '1', extension: 'mkv', resolution: '720p', formatString: '1 - best', filesize: 200);
        expect(a == b, isTrue);
      });

      test('U-DL-FMT-12: considers formats unequal if formatId differs', () {
        const a = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: 'best');
        const b = MediaFormat(formatId: '2', extension: 'mp4', resolution: '1080p', formatString: 'best');
        expect(a == b, isFalse);
      });

      test('U-DL-FMT-13: considers formats unequal if formatString differs', () {
        const a = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: '1 - best');
        const b = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: '1 - worst');
        expect(a == b, isFalse);
      });

      test('U-DL-FMT-14: passes identity check', () {
        const a = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: '1 - best');
        expect(identical(a, a), isTrue);
        expect(a == a, isTrue);
      });

      test('U-DL-FMT-15: generates identical hash codes for equal objects', () {
        const a = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: '1 - best', filesize: 100);
        const b = MediaFormat(formatId: '1', extension: 'mkv', resolution: '720p', formatString: '1 - best', filesize: 200);
        expect(a.hashCode, equals(b.hashCode));
      });

      test('U-DL-FMT-16: generates different hash codes for unequal objects', () {
        const a = MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: 'best');
        const b = MediaFormat(formatId: '2', extension: 'mp4', resolution: '1080p', formatString: 'best');
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });
    });
  });

  group('MediaInfo Entity Tests', () {
    // ═══════════════════════════════════════════════════════════════
    // 4. MediaInfo — JSON Parsing (fromJson)
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — JSON Parsing (fromJson)', () {
      test('U-DL-MIN-01: parses complete standard yt-dlp metadata', () {
        final json = {
          'id': 'abc',
          'title': 'My Video',
          'formats': [
            {'format_id': '137', 'ext': 'mp4'}
          ],
          'duration': 120,
          'extractor': 'youtube',
          'webpage_url': 'https://youtube.com/watch?v=abc',
        };
        final info = MediaInfo.fromJson(json);

        expect(info.id, 'abc');
        expect(info.title, 'My Video');
        expect(info.formats.length, 1);
        expect(info.duration, 120);
        expect(info.extractor, 'youtube');
        expect(info.originalUrl, 'https://youtube.com/watch?v=abc');
      });

      test('U-DL-MIN-02: gracefully handles missing non-required fields', () {
        final json = {
          'id': 'abc',
          'title': 'My Video',
        };
        final info = MediaInfo.fromJson(json);

        expect(info.filesize, isNull);
        expect(info.thumbnail, isNull);
        expect(info.duration, isNull);
      });

      test('U-DL-MIN-03: uses originalUrl parameter when webpage_url is absent', () {
        final info = MediaInfo.fromJson({'id': '1'}, originalUrl: 'https://example.com');
        expect(info.originalUrl, 'https://example.com');
      });

      test('U-DL-MIN-04: fallbacks originalUrl to webpage_url from JSON', () {
        final json = {'webpage_url': 'https://example.com'};
        final info = MediaInfo.fromJson(json);
        expect(info.originalUrl, 'https://example.com');
      });

      test('U-DL-MIN-05: handles empty formats list', () {
        final json = {'formats': []};
        final info = MediaInfo.fromJson(json);
        expect(info.formats, isEmpty);
      });

      test('U-DL-MIN-06: handles null formats list', () {
        final json = {'formats': null};
        final info = MediaInfo.fromJson(json);
        expect(info.formats, isEmpty);
      });

      test('U-DL-MIN-07: parses filesize fallback chain', () {
        final json = {
          'filesize': null,
          'filesize_approx': null,
          'file_size': null,
          'size': 999,
        };
        final info = MediaInfo.fromJson(json);
        expect(info.filesize, 999);
      });

      test('U-DL-MIN-08: parses isLive flag', () {
        final json = {'is_live': true};
        final info = MediaInfo.fromJson(json);
        expect(info.isLive, isTrue);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 5. MediaInfo — Title Parsing & Fallbacks
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — Title Parsing & Fallbacks', () {
      test('U-DL-MIN-09: uses JSON title field directly', () {
        final info = MediaInfo.fromJson({'title': 'My Video'});
        expect(info.title, 'My Video');
      });

      test('U-DL-MIN-10: extracts path segment from URL when title is empty', () {
        final info = MediaInfo.fromJson({'title': ''}, originalUrl: 'https://example.com/my-page/file');
        expect(info.title, 'my-page');
      });

      test('U-DL-MIN-11: prepends @ for Instagram/X/Twitter URLs', () {
        final info1 = MediaInfo.fromJson({'title': ''}, originalUrl: 'https://instagram.com/johndoe');
        expect(info1.title, '@johndoe');

        final info2 = MediaInfo.fromJson({'title': ''}, originalUrl: 'https://x.com/janedoe');
        expect(info2.title, '@janedoe');
      });

      test('U-DL-MIN-12: fallbacks to "Unknown Playlist" for playlists', () {
        final info = MediaInfo.fromJson({'title': '', '_type': 'playlist'});
        expect(info.title, 'Unknown Playlist');
      });

      test('U-DL-MIN-13: fallbacks to "Unknown Title" for singles', () {
        final info = MediaInfo.fromJson({'title': ''});
        expect(info.title, 'Unknown Title');
      });

      test('U-DL-MIN-14: handles unparseable URL in title fallback', () {
        final info = MediaInfo.fromJson({'title': ''}, originalUrl: ':::invalid');
        expect(info.title, 'Unknown Title');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 6. MediaInfo — isVideo Detection
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — isVideo Detection', () {
      test('U-DL-MIN-15: detects video from vcodec field', () {
        final info = MediaInfo.fromJson({'vcodec': 'avc1'});
        expect(info.isVideo, isTrue);
      });

      test('U-DL-MIN-16: detects non-video when vcodec is "none"', () {
        final info = MediaInfo.fromJson({'vcodec': 'none'});
        expect(info.isVideo, isFalse);
      });

      test('U-DL-MIN-17: defaults to video if formats exist but no vcodec', () {
        final info = MediaInfo.fromJson({
          'formats': [{'ext': 'mp4'}]
        });
        expect(info.isVideo, isTrue);
      });

      test('U-DL-MIN-18: detects video from extension field', () {
        final info = MediaInfo.fromJson({'extension': 'mp4'});
        expect(info.isVideo, isTrue);
      });

      test('U-DL-MIN-19: detects non-video extension', () {
        final info = MediaInfo.fromJson({'extension': 'jpg'});
        expect(info.isVideo, isFalse);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 7. MediaInfo — Playlist & Item Count
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — Playlist & Item Count', () {
      test('U-DL-MIN-20: detects playlist from _type field', () {
        final info = MediaInfo.fromJson({'_type': 'playlist'});
        expect(info.isPlaylist, isTrue);
      });

      test('U-DL-MIN-21: extracts itemCount from playlist_count', () {
        final info = MediaInfo.fromJson({'_type': 'playlist', 'playlist_count': 25});
        expect(info.itemCount, 25);
      });

      test('U-DL-MIN-22: extracts itemCount from entries list length', () {
        final info = MediaInfo.fromJson({
          '_type': 'playlist',
          'entries': [1, 2, 3]
        });
        expect(info.itemCount, 3);
      });

      test('U-DL-MIN-23: itemCount is null for non-playlists', () {
        final info = MediaInfo.fromJson({});
        expect(info.itemCount, isNull);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 8. MediaInfo — Thumbnail Extraction
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — Thumbnail Extraction', () {
      test('U-DL-MIN-24: extracts thumbnail from direct field', () {
        final info = MediaInfo.fromJson({'thumbnail': 'https://img.jpg'});
        expect(info.thumbnail, 'https://img.jpg');
      });

      test('U-DL-MIN-25: extracts thumbnail from thumbnails list (last element)', () {
        final json = {
          'thumbnails': [
            {'url': 'a'},
            {'url': 'b'}
          ]
        };
        final info = MediaInfo.fromJson(json);
        expect(info.thumbnail, 'b');
      });

      test('U-DL-MIN-26: handles empty thumbnails list', () {
        final json = {'thumbnails': []};
        final info = MediaInfo.fromJson(json);
        expect(info.thumbnail, isNull);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 9. MediaInfo — copyWith
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — copyWith', () {
      test('U-DL-MIN-27: overrides single field', () {
        final info = MediaInfo.fromJson({'title': 'Old'});
        final newInfo = info.copyWith(title: 'New');
        expect(newInfo.title, 'New');
        expect(newInfo.originalUrl, info.originalUrl); // unchanged
      });

      test('U-DL-MIN-28: overrides multiple fields', () {
        const info = MediaInfo(id: '1', title: 'T', originalUrl: 'U');
        final newInfo = info.copyWith(isProfile: true, thumbnail: 'url', galleryIndex: 5);

        expect(newInfo.isProfile, isTrue);
        expect(newInfo.thumbnail, 'url');
        expect(newInfo.galleryIndex, 5);
        expect(newInfo.id, '1');
      });

      test('U-DL-MIN-29: no-arg call preserves all fields', () {
        const info = MediaInfo(id: '1', title: 'T', originalUrl: 'U', isVideo: false);
        final newInfo = info.copyWith();
        expect(newInfo.id, info.id);
        expect(newInfo.title, info.title);
        expect(newInfo.originalUrl, info.originalUrl);
        expect(newInfo.isVideo, info.isVideo);
      });

      test('U-DL-MIN-30: overrides engineId and fetchLogs', () {
        const info = MediaInfo(id: '1', title: 'T', originalUrl: 'U');
        final newInfo = info.copyWith(engineId: 'gallery-dl', fetchLogs: 'log...');
        expect(newInfo.engineId, 'gallery-dl');
        expect(newInfo.fetchLogs, 'log...');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 10. MediaInfo — Map Serialization
    // ═══════════════════════════════════════════════════════════════
    group('MediaInfo — Map Serialization', () {
      test('U-DL-MIN-31: serializes all fields including formats', () {
        const info = MediaInfo(
          id: '1',
          title: 'T',
          originalUrl: 'U',
          formats: [
            MediaFormat(formatId: 'a', extension: 'b', resolution: 'c', formatString: 'd'),
            MediaFormat(formatId: 'e', extension: 'f', resolution: 'g', formatString: 'h'),
          ],
        );
        final map = info.toMap();
        expect(map['id'], '1');
        expect(map['title'], 'T');
        expect(map['originalUrl'], 'U');
        expect((map['formats'] as List).length, 2);
      });

      test('U-DL-MIN-32: omits null optional fields', () {
        const info = MediaInfo(id: '1', title: 'T', originalUrl: 'U');
        final map = info.toMap();
        expect(map.containsKey('thumbnail'), isFalse);
        expect(map.containsKey('duration'), isFalse);
        expect(map.containsKey('directUrl'), isFalse);
      });

      test('U-DL-MIN-33: conditionally includes isLive only when true', () {
        const info = MediaInfo(id: '1', title: 'T', originalUrl: 'U');
        final map = info.toMap();
        expect(map.containsKey('isLive'), isFalse);

        const info2 = MediaInfo(id: '2', title: 'T2', originalUrl: 'U2', isLive: true);
        final map2 = info2.toMap();
        expect(map2['isLive'], isTrue);
      });

      test('U-DL-MIN-34: deserializes from Map with all fields', () {
        final map = {
          'id': '1',
          'title': 'T',
          'originalUrl': 'U',
          'isVideo': false,
          'isError': true,
        };
        final info = MediaInfo.fromMap(map);
        expect(info.id, '1');
        expect(info.title, 'T');
        expect(info.originalUrl, 'U');
        expect(info.isVideo, isFalse);
        expect(info.isError, isTrue);
      });

      test('U-DL-MIN-35: supports round-trip serialization', () {
        const original = MediaInfo(
          id: '1',
          title: 'T',
          originalUrl: 'U',
          isVideo: false,
          isError: true,
          errorMessage: 'Error',
        );
        final map = original.toMap();
        final result = MediaInfo.fromMap(map);

        expect(result.id, original.id);
        expect(result.title, original.title);
        expect(result.originalUrl, original.originalUrl);
        expect(result.isVideo, original.isVideo);
        expect(result.isError, original.isError);
        expect(result.errorMessage, original.errorMessage);
      });

      test('U-DL-MIN-36: provides default values for missing keys', () {
        final map = {
          'id': '1',
          'originalUrl': 'U',
        };
        final info = MediaInfo.fromMap(map);
        expect(info.title, '');
        expect(info.isVideo, isTrue);
        expect(info.formats, isEmpty);
        expect(info.isPlaylist, isFalse);
      });
    });
  });

  group('MediaGroup Entity Tests', () {
    // ═══════════════════════════════════════════════════════════════
    // 11. MediaGroup — Construction & Getters
    // ═══════════════════════════════════════════════════════════════
    group('MediaGroup — Construction & Getters', () {
      test('U-DL-GRP-01: returns true if 1 item in group', () {
        const group = MediaGroup(originalUrl: 'U', items: [MediaInfo(id: '1', title: 'T', originalUrl: 'U')]);
        expect(group.isSingle, isTrue);
      });

      test('U-DL-GRP-02: returns true if 0 items in group', () {
        const group = MediaGroup(originalUrl: 'U', items: []);
        expect(group.isSingle, isTrue);
      });

      test('U-DL-GRP-03: returns false if 2+ items', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T1', originalUrl: 'U'),
            MediaInfo(id: '2', title: 'T2', originalUrl: 'U'),
          ],
        );
        expect(group.isSingle, isFalse);
      });

      test('U-DL-GRP-04: returns first item', () {
        const item1 = MediaInfo(id: '1', title: 'T1', originalUrl: 'U');
        const item2 = MediaInfo(id: '2', title: 'T2', originalUrl: 'U');
        const group = MediaGroup(originalUrl: 'U', items: [item1, item2]);
        expect(group.first, item1);
      });

      test('U-DL-GRP-05: throws on empty items when accessing first', () {
        const group = MediaGroup(originalUrl: 'U', items: []);
        expect(() => group.first, throwsStateError);
      });

      test('U-DL-GRP-06: correctly counts based on isVideo flags', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U'),
            MediaInfo(id: '2', title: 'T', originalUrl: 'U'),
            MediaInfo(id: '3', title: 'T', originalUrl: 'U', isVideo: false),
            MediaInfo(id: '4', title: 'T', originalUrl: 'U', isVideo: false),
            MediaInfo(id: '5', title: 'T', originalUrl: 'U', isVideo: false),
          ],
        );
        expect(group.videoCount, 2);
        expect(group.imageCount, 3);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 12. MediaGroup — Total Filesize Estimation
    // ═══════════════════════════════════════════════════════════════
    group('MediaGroup — Total Filesize Estimation', () {
      test('U-DL-GRP-07: sums exact filesizes correctly if all have known sizes', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', filesize: 10485760), // 10MB
            MediaInfo(id: '2', title: 'T', originalUrl: 'U', filesize: 5242880), // 5MB
          ],
        );
        expect(group.totalFilesize, 15728640);
      });

      test('U-DL-GRP-08: estimates missing video sizes using average of known videos', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', filesize: 10485760), // 10MB
            MediaInfo(id: '2', title: 'T', originalUrl: 'U'),
          ],
        );
        // Average is 10MB. 10MB (known) + 10MB (estimated) = 20MB
        expect(group.totalFilesize, 20971520);
      });

      test('U-DL-GRP-09: estimates missing image sizes using average of known images', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', filesize: 2097152, isVideo: false), // 2MB
            MediaInfo(id: '2', title: 'T', originalUrl: 'U', isVideo: false),
          ],
        );
        // Average is 2MB. 2MB + 2MB = 4MB
        expect(group.totalFilesize, 4194304);
      });

      test('U-DL-GRP-10: fallbacks to hardcoded video constant if NO videos have known sizes', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U'),
            MediaInfo(id: '2', title: 'T', originalUrl: 'U'),
          ],
        );
        // 2 videos * 15MB = 30MB
        expect(group.totalFilesize, 30 * 1024 * 1024);
      });

      test('U-DL-GRP-11: fallbacks to hardcoded image constant if NO images have known sizes', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', isVideo: false),
            MediaInfo(id: '2', title: 'T', originalUrl: 'U', isVideo: false),
          ],
        );
        // 2 images * 1MB = 2MB
        expect(group.totalFilesize, 2 * 1024 * 1024);
      });

      test('U-DL-GRP-12: mixed video + image with mixed known/unknown sizes', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', filesize: 10 * 1024 * 1024),
            MediaInfo(id: '2', title: 'T', originalUrl: 'U'),
            MediaInfo(id: '3', title: 'T', originalUrl: 'U', filesize: 2 * 1024 * 1024, isVideo: false),
            MediaInfo(id: '4', title: 'T', originalUrl: 'U', isVideo: false),
          ],
        );
        // Vid: 10 + 10 = 20MB. Img: 2 + 2 = 4MB. Total = 24MB.
        expect(group.totalFilesize, 24 * 1024 * 1024);
      });

      test('U-DL-GRP-13: excludes error items from total size', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', filesize: 100),
            MediaInfo(id: '2', title: 'T', originalUrl: 'U', filesize: 200, isError: true),
          ],
        );
        expect(group.totalFilesize, 100);
      });

      test('U-DL-GRP-14: returns 0 for empty group total size', () {
        const group = MediaGroup(originalUrl: 'U', items: []);
        expect(group.totalFilesize, 0);
      });

      test('U-DL-GRP-15: sums massive filesizes without integer overflow', () {
        const size5GB = 5000000000;
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T', originalUrl: 'U', filesize: size5GB),
            MediaInfo(id: '2', title: 'T', originalUrl: 'U', filesize: size5GB),
            MediaInfo(id: '3', title: 'T', originalUrl: 'U', filesize: size5GB),
          ],
        );
        expect(group.totalFilesize, 15000000000);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 13. MediaGroup — Map Serialization
    // ═══════════════════════════════════════════════════════════════
    group('MediaGroup — Map Serialization', () {
      test('U-DL-GRP-16: serializes group with items', () {
        const group = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T1', originalUrl: 'U'),
            MediaInfo(id: '2', title: 'T2', originalUrl: 'U'),
          ],
        );
        final map = group.toMap();
        expect(map['originalUrl'], 'U');
        expect((map['items'] as List).length, 2);
      });

      test('U-DL-GRP-17: deserializes group from Map', () {
        final map = {
          'originalUrl': 'U',
          'items': [
            {'id': '1', 'title': 'T1'},
            {'id': '2', 'title': 'T2'}
          ]
        };
        final group = MediaGroup.fromMap(map);
        expect(group.originalUrl, 'U');
        expect(group.items.length, 2);
        expect(group.items[0].id, '1');
        expect(group.items[1].id, '2');
      });

      test('U-DL-GRP-18: supports round-trip serialization', () {
        const original = MediaGroup(
          originalUrl: 'U',
          items: [
            MediaInfo(id: '1', title: 'T1', originalUrl: 'U'),
          ],
        );
        final map = original.toMap();
        final result = MediaGroup.fromMap(map);
        expect(result.originalUrl, original.originalUrl);
        expect(result.items.length, 1);
        expect(result.items[0].id, original.items[0].id);
      });

      test('U-DL-GRP-19: handles missing items key', () {
        final map = {'originalUrl': 'U'};
        final group = MediaGroup.fromMap(map);
        expect(group.items, isEmpty);
      });
    });
  });
}
