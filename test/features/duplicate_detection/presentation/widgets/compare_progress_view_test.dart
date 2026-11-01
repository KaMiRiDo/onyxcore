import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_progress_view.dart';

void main() {
  group('CompareProgressView', () {
    testWidgets('renders progress info and cancel button', (tester) async {
      var cancelled = false;
      const progress = ComparisonProgress(
        requestId: '/source',
        status: ComparisonStatus.clustering,
        processedFiles: 42,
        totalFiles: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompareProgressView(
              progress: progress,
              onCancel: () {
                cancelled = true;
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('clustering'), findsOneWidget);
      expect(find.textContaining('42 / 100'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);
    });
  });
}
