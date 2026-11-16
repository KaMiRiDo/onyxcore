import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/file_comparison_tile.dart';

void main() {
  group('FileComparisonTile', () {
    late Directory tempDir;
    late File sourceFile;
    late File destFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tile_test_');
      sourceFile = File('${tempDir.path}/photo_source.jpg')
        ..writeAsBytesSync(List.filled(2048, 42));
      destFile = File('${tempDir.path}/photo_dest.jpg')
        ..writeAsBytesSync(List.filled(4096, 42));
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders source file details, badge, and size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileComparisonTile(filePath: sourceFile.path, isSource: true),
          ),
        ),
      );

      expect(find.text('SOURCE'), findsOneWidget);
      expect(find.text('photo_source.jpg'), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);
    });

    testWidgets('renders destination file with exact match badge and score', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileComparisonTile(
              filePath: destFile.path,
              isSource: false,
              matchType: MatchType.exact,
              similarityScore: 1,
            ),
          ),
        ),
      );

      expect(find.text('DESTINATION'), findsOneWidget);
      expect(find.text('photo_dest.jpg'), findsOneWidget);
      expect(find.text('Exact Match'), findsOneWidget);
      expect(find.textContaining('4.0 KB'), findsOneWidget);
    });

    testWidgets('renders destination file with perceptual match percentage', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileComparisonTile(
              filePath: destFile.path,
              isSource: false,
              matchType: MatchType.perceptual,
              similarityScore: 0.94,
            ),
          ),
        ),
      );

      expect(find.text('DESTINATION'), findsOneWidget);
      expect(find.text('94% Similarity'), findsOneWidget);
    });

    testWidgets('handles non-existent or deleted file gracefully', (
      tester,
    ) async {
      final missingPath = '${tempDir.path}/deleted_photo.jpg';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileComparisonTile(filePath: missingPath, isSource: true),
          ),
        ),
      );

      expect(find.text('deleted_photo.jpg'), findsOneWidget);
      expect(find.textContaining('Unavailable'), findsOneWidget);
    });

    testWidgets(
      'clicking on top link button triggers onLocate and does not invoke onOpen',
      (tester) async {
        var opened = false;
        var located = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileComparisonTile(
                filePath: sourceFile.path,
                isSource: true,
                onOpen: () => opened = true,
                onLocate: () => located = true,
              ),
            ),
          ),
        );

        final linkBtn = find.byTooltip('Locate in Directory');
        expect(linkBtn, findsOneWidget);
        await tester.tap(linkBtn);
        await tester.pumpAndSettle();

        expect(located, isTrue);
        expect(opened, isFalse);
      },
    );

    testWidgets(
      'double clicking on tile triggers onOpen to open in respective viewer',
      (tester) async {
        var opened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileComparisonTile(
                filePath: sourceFile.path,
                isSource: true,
                onOpen: () => opened = true,
              ),
            ),
          ),
        );

        final tileFinder = find.byType(FileComparisonTile);
        await tester.tap(tileFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(tileFinder);
        await tester.pumpAndSettle();

        expect(opened, isTrue);
      },
    );

    testWidgets(
      'double clicking on file name text triggers onOpen reliably',
      (tester) async {
        var opened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileComparisonTile(
                filePath: sourceFile.path,
                isSource: true,
                onOpen: () => opened = true,
              ),
            ),
          ),
        );

        final fileNameFinder = find.text('photo_source.jpg');
        expect(fileNameFinder, findsOneWidget);
        await tester.tap(fileNameFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(fileNameFinder);
        await tester.pumpAndSettle();

        expect(opened, isTrue);
      },
    );

    testWidgets(
      'double clicking on thumbnail preview triggers onOpen reliably',
      (tester) async {
        var opened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileComparisonTile(
                filePath: sourceFile.path,
                isSource: true,
                onOpen: () => opened = true,
              ),
            ),
          ),
        );

        final previewFinder = find.byType(Image);
        expect(previewFinder, findsOneWidget);
        await tester.tap(previewFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(previewFinder);
        await tester.pumpAndSettle();

        expect(opened, isTrue);
      },
    );

    testWidgets(
      'FileComparisonTile enables gaplessPlayback and bounds image decode cache to avoid flicker',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileComparisonTile(
                filePath: sourceFile.path,
                isSource: true,
              ),
            ),
          ),
        );

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);

        final imageWidget = tester.widget<Image>(imageFinder);
        expect(imageWidget.gaplessPlayback, isTrue);

        final resizeProvider = imageWidget.image as ResizeImage;
        expect(resizeProvider.width, lessThanOrEqualTo(160));
        expect(resizeProvider.height, lessThanOrEqualTo(160));
      },
    );

    testWidgets(
      'FileComparisonTile safely handles SVG files without passing them to bitmap Image.file',
      (tester) async {
        final svgFile = File('${tempDir.path}/vector_icon.svg')
          ..writeAsStringSync(
            '<svg width="100" height="100"><circle cx="50" cy="50" r="40"/></svg>',
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FileComparisonTile(filePath: svgFile.path, isSource: true),
            ),
          ),
        );

        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(Icons.image_rounded), findsNWidgets(2));
      },
    );
  });
}
