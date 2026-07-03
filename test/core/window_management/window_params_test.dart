import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  group('WindowParams Tests', () {
    final testDate = DateTime.fromMillisecondsSinceEpoch(1620000000000);
    final fileItem = FileItem(
      name: 'test_video.mp4',
      path: '/path/to/test_video.mp4',
      sizeBytes: 1024,
      modified: testDate,
      type: FileItemType.video,
    );

    test('toJson returns correct map', () {
      final params = WindowParams(
        viewerType: ViewerType.video,
        file: fileItem,
        parentWindowId: '100',
        initParams: {'startPositionMs': 5000},
      );

      final json = params.toJson();

      expect(json['viewerType'], 'video');
      expect(json['parentWindowId'], '100');
      expect(json['initParams'], {'startPositionMs': 5000});
      expect(json['file'], {
        'name': 'test_video.mp4',
        'path': '/path/to/test_video.mp4',
        'sizeBytes': 1024,
        'modified': 1620000000000,
        'type': 'video',
      });
    });

    test('fromJson creates correct instance', () {
      final json = {
        'viewerType': 'video',
        'file': {
          'name': 'test_video.mp4',
          'path': '/path/to/test_video.mp4',
          'sizeBytes': 1024,
          'modified': 1620000000000,
          'type': 'video',
        },
        'parentWindowId': '100',
        'initParams': {'startPositionMs': 5000},
      };

      final params = WindowParams.fromJson(json);

      expect(params.viewerType, ViewerType.video);
      expect(params.parentWindowId, '100');
      expect(params.initParams, {'startPositionMs': 5000});
      expect(params.file.name, 'test_video.mp4');
      expect(params.file.path, '/path/to/test_video.mp4');
      expect(params.file.sizeBytes, 1024);
      expect(params.file.modified, testDate);
      expect(params.file.type, FileItemType.video);
    });

    test('fromJson falls back to default types if not found', () {
      final json = {
        'viewerType': 'unknown_type',
        'file': {
          'name': 'test_file.txt',
          'path': '/path/to/test_file.txt',
          'sizeBytes': 1024,
          'modified': 1620000000000,
          'type': 'unknown_type',
        },
        'parentWindowId': null,
        'initParams': <String, dynamic>{},
      };

      final params = WindowParams.fromJson(json);

      expect(params.viewerType, ViewerType.unsupported);
      expect(params.file.type, FileItemType.other);
    });

    test('encode returns valid JSON string', () {
      final params = WindowParams(
        viewerType: ViewerType.image,
        file: fileItem,
      );

      final encoded = params.encode();
      final decoded = jsonDecode(encoded);

      expect(decoded['viewerType'], 'image');
      expect(decoded['file']['name'], 'test_video.mp4');
    });
  });
}
