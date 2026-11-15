import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/file_comparison_tile.dart';

void main() {
  group('FileComparisonTile selection', () {
    late Directory tempDir;
    late File file;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tile_sel_test_');
      file = File('${tempDir.path}/test_item.jpg')
        ..writeAsBytesSync(List.filled(1024, 1));
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders Checkbox with isSelected state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileComparisonTile(
              filePath: file.path,
              isSource: true,
              isSelected: true,
            ),
          ),
        ),
      );

      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      final checkbox = tester.widget<Checkbox>(checkboxFinder);
      expect(checkbox.value, isTrue);
    });

    testWidgets('tapping checkbox invokes onToggleSelect', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileComparisonTile(
              filePath: file.path,
              isSource: false,
              onToggleSelect: () {
                toggled = true;
              },
            ),
          ),
        ),
      );

      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);
      await tester.tap(checkboxFinder);
      await tester.pump();

      expect(toggled, isTrue);
    });
  });
}
