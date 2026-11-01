// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  group('Compare WindowParams Integration', () {
    final testDate = DateTime.fromMillisecondsSinceEpoch(1620000000000);
    final folderItem = FileItem(
      name: 'SourceDir',
      path: '/path/to/SourceDir',
      modified: testDate,
      type: FileItemType.folder,
    );

    test('serializes duplicateCompare viewer type and initParams to JSON', () {
      final params = WindowParams(
        viewerType: ViewerType.duplicateCompare,
        file: folderItem,
        initParams: {
          'sourceFolder': '/path/to/SourceDir',
          'destinationFolder': '/path/to/DestDir',
          'category': 'images',
        },
      );

      final json = params.toJson();

      expect(json['viewerType'], 'duplicateCompare');
      expect(json['initParams']['sourceFolder'], '/path/to/SourceDir');
      expect(json['initParams']['destinationFolder'], '/path/to/DestDir');
      expect(json['initParams']['category'], 'images');
      expect(json['file']['path'], '/path/to/SourceDir');
      expect(json['file']['type'], 'folder');
    });

    test(
      'deserializes duplicateCompare viewer type and initParams from JSON',
      () {
        final json = {
          'viewerType': 'duplicateCompare',
          'file': {
            'name': 'SourceDir',
            'path': '/path/to/SourceDir',
            'sizeBytes': null,
            'modified': 1620000000000,
            'type': 'folder',
          },
          'parentWindowId': null,
          'initParams': {
            'sourceFolder': '/path/to/SourceDir',
            'destinationFolder': '/path/to/DestDir',
            'category': 'images',
          },
        };

        final params = WindowParams.fromJson(json);

        expect(params.viewerType, ViewerType.duplicateCompare);
        expect(params.initParams['sourceFolder'], '/path/to/SourceDir');
        expect(params.initParams['destinationFolder'], '/path/to/DestDir');
        expect(params.initParams['category'], 'images');
        expect(params.file.path, '/path/to/SourceDir');
        expect(params.file.type, FileItemType.folder);
      },
    );

    test('round-trip encode and decode preserves duplicateCompare config', () {
      final params = WindowParams(
        viewerType: ViewerType.duplicateCompare,
        file: folderItem,
        initParams: {
          'sourceFolder': '/path/to/SourceDir',
          'destinationFolder': '/path/to/DestDir',
        },
      );

      final encoded = params.encode();
      final decodedJson = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = WindowParams.fromJson(decodedJson);

      expect(restored.viewerType, ViewerType.duplicateCompare);
      expect(restored.initParams['sourceFolder'], '/path/to/SourceDir');
      expect(restored.initParams['destinationFolder'], '/path/to/DestDir');
    });
  });
}
