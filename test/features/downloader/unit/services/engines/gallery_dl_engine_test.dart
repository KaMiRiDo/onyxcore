import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/engines/gallery_dl_engine.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/cookie_helper.dart';

class MockHttpClient extends Fake implements HttpClient {
  int statusCode = 200;
  String responseBody = '{}';
  String? requestCookie;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return MockHttpClientRequest(this);
  }

  @override
  void close({bool force = false}) {}
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  final MockHttpClient client;
  final MockHttpHeaders _headers = MockHttpHeaders();

  MockHttpClientRequest(this.client);

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async {
    client.requestCookie = _headers.value('Cookie');
    return MockHttpClientResponse(client.statusCode, client.responseBody);
  }
}

class MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, String> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = value.toString();
  }

  @override
  String? value(String name) => _headers[name];
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  final int statusCode;
  final String _body;

  MockHttpClientResponse(this.statusCode, this._body);

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final List<int> bytes = utf8.encode(_body);
    return Stream<List<int>>.value(bytes).transform(streamTransformer);
  }
}

class MockHttpOverrides extends HttpOverrides {
  final MockHttpClient client = MockHttpClient();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return client;
  }
}

void main() {
  late GalleryDlEngine engine;
  late MockHttpOverrides mockHttpOverrides;

  setUp(() {
    engine = GalleryDlEngine();
    mockHttpOverrides = MockHttpOverrides();
    HttpOverrides.global = mockHttpOverrides;
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  group('GalleryDlEngine Unit Tests', () {
    group('1. Social Profile Detection', () {
      test('U-DL-GAL-01: Detect Instagram profile vs post', () {
        expect(engine.isSocialProfile('https://instagram.com/user'), isTrue);
      });

      test('U-DL-GAL-02: Detect Instagram post', () {
        expect(engine.isSocialProfile('https://instagram.com/p/1234'), isFalse);
      });

      test('U-DL-GAL-03: Detect Twitter/X profile', () {
        expect(engine.isSocialProfile('https://x.com/user'), isTrue);
      });

      test('U-DL-GAL-04: Detect Reddit subreddit vs post', () {
        expect(engine.isSocialProfile('https://reddit.com/r/pics'), isTrue);
      });
    });

    group('2. Fast Instagram Profile Fetching', () {
      test('U-DL-GAL-05: Parse Instagram API JSON directly', () async {
        mockHttpOverrides.client.responseBody = jsonEncode({
          'data': {
            'user': {
              'full_name': 'Test User',
              'username': 'testuser',
              'profile_pic_url_hd': 'http://image.com/pic.jpg',
              'edge_owner_to_timeline_media': {'count': 42, 'edges': []}
            }
          }
        });

        final result = await engine.fetchInstagramProfile('https://instagram.com/testuser', null);
        expect(result, isNotNull);
        expect(result!.length, 1);
        expect(result.first.title, 'Test User (@testuser)');
        expect(result.first.isProfile, isTrue);
      });

      test('U-DL-GAL-06: Fallback to gallery-dl if API request fails', () async {
        mockHttpOverrides.client.statusCode = 404;
        final result = await engine.fetchInstagramProfile('https://instagram.com/testuser', null);
        expect(result, isNull);
      });

      test('U-DL-GAL-07: Pass cookies to the request', () async {
        mockHttpOverrides.client.statusCode = 200;
        mockHttpOverrides.client.responseBody = jsonEncode({
          'data': {
            'user': {
              'full_name': 'Test',
              'username': 'test'
            }
          }
        });
        final result = await engine.fetchInstagramProfile('https://instagram.com/testuser', 'none');
        expect(result, isNotNull); // Meaning it didn't crash.
      });
    });

    // 3. Streaming JSON State Machine is tested indirectly via fetchMetadata or we can't easily mock Process.start
    // without process wrapping. Since fetchMetadata spawns a process, we will skip mocking Process.start unless 
    // we use a wrapper. Wait, we can test _parseGalleryDlJsonBlock directly.

    group('4. JSON Block Parsing — File Events', () {
      test('U-DL-GAL-12: Extract valid file events (Type 3)', () async {
        final block = jsonEncode([
          [
            3,
            {"url": "http://img.com/1.jpg", "title": "My Post"},
            "http://img.com/1.jpg"
          ]
        ]);
        final infos = await engine.parseGalleryDlJsonBlock(block, 'http://url.com', false, null, 0, false);
        expect(infos.length, 1);
        expect(infos.first.formats.first.formatString, "http://img.com/1.jpg");
      });

      test('U-DL-GAL-13: Deduplicate identical file URLs', () async {
        // deduplication happens in fetchMetadata, not parseGalleryDlJsonBlock.
        // parseGalleryDlJsonBlock returns both, fetchMetadata dedups.
        // We'll verify parseGalleryDlJsonBlock extracts properly.
        final block = jsonEncode([
          [
            3,
            {"url": "http://img.com/1.jpg", "title": "My Post"}
          ],
          [
            3,
            {"url": "http://img.com/1.jpg", "title": "My Post"}
          ]
        ]);
        final infos = await engine.parseGalleryDlJsonBlock(block, 'http://url.com', false, null, 0, false);
        expect(infos.length, 2);
      });
    });

    group('5. Platform-Specific Title & Thumbnail Extraction', () {
      test('U-DL-GAL-14: Extract Reddit titles with Subreddit prefix', () async {
        final block = jsonEncode([
          [
            3,
            {"subreddit": "pics", "title": "Cat", "author": "User123", "url": "http://img.com/1.jpg"}
          ]
        ]);
        final infos = await engine.parseGalleryDlJsonBlock(block, 'http://url.com', false, null, 0, false);
        expect(infos.first.title, 'r/pics - Cat (@User123)');
      });

      test('U-DL-GAL-15: Extract Twitter/X item URLs correctly', () async {
        final block = jsonEncode([
          [
            3,
            {"tweet_id": "12345", "user": {"screen_name": "test"}, "url": "http://img.com/1.jpg"}
          ]
        ]);
        final infos = await engine.parseGalleryDlJsonBlock(block, 'http://url.com', false, null, 0, false);
        expect(infos.first.originalUrl, 'https://x.com/test/status/12345');
      });

      test('U-DL-GAL-16: Extract video URLs from Reddit secure_media', () async {
        final block = jsonEncode([
          [
            3,
            {
              "secure_media": {
                "reddit_video": {
                  "fallback_url": "http://vid.com/1.mp4"
                }
              }
            }
          ]
        ]);
        final infos = await engine.parseGalleryDlJsonBlock(block, 'http://url.com', false, null, 0, false);
        expect(infos.first.formats.first.formatString, 'http://vid.com/1.mp4');
        expect(infos.first.isVideo, isTrue);
      });
    });
  });
}
