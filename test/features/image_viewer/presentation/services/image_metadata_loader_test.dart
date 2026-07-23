import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/services/image_metadata_loader.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageMetadataLoader', () {
    late String testDirPath;
    late String dummyJpgPath;
    late String dummySvgPath;
    late String nonExistentPath;
    late String corruptJpgPath;

    setUpAll(() async {
      final tempDir = Directory.systemTemp;
      testDirPath = p.join(tempDir.path, 'image_metadata_loader_test');
      final dir = Directory(testDirPath);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync();

      // Create a dummy valid image (a 1x1 white pixel in JPEG format)
      dummyJpgPath = p.join(testDirPath, 'valid.jpg');
      final validJpgBytes = [
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
        0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xc0,
        0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xff,
        0xc4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xc4, 0x00,
        0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xda, 0x00, 0x08, 0x01,
        0x01, 0x00, 0x00, 0x3f, 0x00, 0x3f, 0xff, 0xd9
      ];
      File(dummyJpgPath).writeAsBytesSync(validJpgBytes);

      dummySvgPath = p.join(testDirPath, 'valid.svg');
      File(dummySvgPath).writeAsStringSync('<svg></svg>');

      nonExistentPath = p.join(testDirPath, 'missing.jpg');

      corruptJpgPath = p.join(testDirPath, 'corrupt.jpg');
      File(corruptJpgPath).writeAsBytesSync([0x00, 0x00, 0x00]); // Invalid
    });

    tearDownAll(() {
      final dir = Directory(testDirPath);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    testWidgets('returns SVG metadata for .svg files', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));
      ImageMetadata? result;
      await tester.runAsync(() async {
        result = await ImageMetadataLoader.load(dummySvgPath, context, Future.value());
      });

      expect(result?.metadataString, 'Vector Graphic • Scalable');
      expect(result?.imageSize, null);
    });

    testWidgets('returns raster metadata for valid images', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));
      ImageMetadata? result;
      await tester.runAsync(() async {
        result = await ImageMetadataLoader.load(dummyJpgPath, context, Future.value());
      });

      expect(result?.metadataString, '1x1 px • 0.0 MP');
      expect(result?.imageSize, const Size(1, 1));
    });

    testWidgets('returns null metadata for missing file', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));
      ImageMetadata? result;
      await tester.runAsync(() async {
        result = await ImageMetadataLoader.load(nonExistentPath, context, Future.value());
      });

      expect(result?.metadataString, isNull);
      expect(result?.imageSize, isNull);
    });

    testWidgets('handles decode error gracefully', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      final context = tester.element(find.byType(Container));
      ImageMetadata? result;
      await tester.runAsync(() async {
        result = await ImageMetadataLoader.load(corruptJpgPath, context, Future.value());
      });

      expect(result?.metadataString, isNull);
      expect(result?.imageSize, isNull);
    });
  });
}
