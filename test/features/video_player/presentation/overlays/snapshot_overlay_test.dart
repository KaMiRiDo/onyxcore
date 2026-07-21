import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/snapshot_overlay.dart';

void main() {
  group('SnapshotOverlay Widget Tests', () {
    testWidgets('SnapshotFlash renders correctly when visible and hidden', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SnapshotFlash(isVisible: true),
          ),
        ),
      );

      // Verify the widget is in the tree
      expect(find.byType(SnapshotFlash), findsOneWidget);
      
      // Check opacity
      final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 0.3);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SnapshotFlash(isVisible: false),
          ),
        ),
      );

      final AnimatedOpacity hiddenOpacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(hiddenOpacityWidget.opacity, 0.0);
    });

    testWidgets('SnapshotToast renders correctly when visible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SnapshotToast(isVisible: true),
          ),
        ),
      );

      expect(find.byType(SnapshotToast), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.text('Snapshot saved to Snapshots/'), findsOneWidget);

      final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 1.0);
    });

    testWidgets('SnapshotToast is not rendered when invisible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SnapshotToast(isVisible: false),
          ),
        ),
      );

      expect(find.byType(SnapshotToast), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsNothing);
      expect(find.text('Snapshot saved to Snapshots/'), findsNothing);
    });
  });
}
