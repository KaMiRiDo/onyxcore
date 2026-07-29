import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';

void main() {
  group('MediaUriHelper.getSafeMediaUri', () {
    test('U-URI-01: returns https:// URL unchanged', () {
      const url = 'https://cdn.example.com/video.mp4';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-02: returns http:// URL unchanged', () {
      const url = 'http://cdn.example.com/video.mp4';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-03: returns rtmp:// URL unchanged', () {
      const url = 'rtmp://stream.example.com/live/stream';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-04: returns rtsp:// URL unchanged', () {
      const url = 'rtsp://stream.example.com/video';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-05: converts local unix path to file:// URI', () {
      const path = '/home/user/videos/file.mp4';
      final result = MediaUriHelper.getSafeMediaUri(path);
      expect(result, 'file:///home/user/videos/file.mp4');
    });

    test('U-URI-06: returns HLS m3u8 manifest URL unchanged', () {
      const url = 'https://cdn.example.com/hls/stream.m3u8';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-07: returns https URL with query params unchanged', () {
      const url = 'https://cdn.example.com/v.mp4?token=abc123&expire=9999';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });
  });

  group('MediaUriHelper local proxy tests', () {
    late Directory tempDir;
    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('media_uri_proxy_test_');
      File('${tempDir.path}\\test_file.txt')
          .writeAsStringSync('abcdefghijklmnopqrstuvwxyz'); // 26 bytes
      await MediaUriHelper.ensureLocalProxy();
    });

    tearDownAll(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('path with backslash maps to proxy and can be requested', () async {
      final pathWithBackslash = '${tempDir.path}\\test_file.txt';
      final proxyUrlStr = MediaUriHelper.getSafeMediaUri(pathWithBackslash);

      expect(proxyUrlStr, startsWith('http://127.0.0.1:'));
      final uri = Uri.parse(proxyUrlStr);

      final client = HttpClient();

      // Test 200 OK (no range header)
      final req200 = await client.getUrl(uri);
      final resp200 = await req200.close();
      expect(resp200.statusCode, HttpStatus.ok);
      expect(resp200.headers.value('Accept-Ranges'), 'bytes');
      expect(resp200.headers.value('Content-Length'), '26');
      final body200 = await resp200.transform(const SystemEncoding().decoder).join();
      expect(body200, 'abcdefghijklmnopqrstuvwxyz');

      // Test 206 Partial Content (range header bytes=2-5)
      final req206 = await client.getUrl(uri);
      req206.headers.add('range', 'bytes=2-5');
      final resp206 = await req206.close();
      expect(resp206.statusCode, HttpStatus.partialContent);
      expect(resp206.headers.value('Content-Range'), 'bytes 2-5/26');
      expect(resp206.headers.value('Content-Length'), '4');
      final body206 = await resp206.transform(const SystemEncoding().decoder).join();
      expect(body206, 'cdef');

      // Test 206 Partial Content (range header bytes=20-)
      final req206End = await client.getUrl(uri);
      req206End.headers.add('range', 'bytes=20-');
      final resp206End = await req206End.close();
      expect(resp206End.statusCode, HttpStatus.partialContent);
      expect(resp206End.headers.value('Content-Range'), 'bytes 20-25/26');
      final body206End = await resp206End.transform(const SystemEncoding().decoder).join();
      expect(body206End, 'uvwxyz');

      client.close();
    });

    test('invalid request returns 404', () async {
      final proxyUrlStr = MediaUriHelper.getSafeMediaUri('${tempDir.path}\\test_file.txt');
      final uri = Uri.parse(proxyUrlStr);
      final badUri = uri.replace(path: '/invalid_id_123');

      final client = HttpClient();
      final req = await client.getUrl(badUri);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.notFound);

      client.close();
    });

    test('deleted mapped file returns 404', () async {
      final missingFile = File('${tempDir.path}/missing_file.txt');
      final pathWithBackslash = '${missingFile.path}\\dummy';
      final proxyUrlStr = MediaUriHelper.getSafeMediaUri(pathWithBackslash);
      final uri = Uri.parse(proxyUrlStr);

      final client = HttpClient();
      final req = await client.getUrl(uri);
      final resp = await req.close();
      expect(resp.statusCode, HttpStatus.notFound);

      client.close();
    });
  });
}
