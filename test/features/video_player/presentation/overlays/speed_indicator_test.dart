import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/speed_indicator.dart';

void main() {
  group('SpeedIndicator', () {
    testWidgets('shows badge when rate > 1.0', (tester) async {
      final controller = StreamController<double>.broadcast();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeedIndicator(
            rateStream: controller.stream,
            currentRate: 1.5,
          ),
        ),
      ));

      expect(find.text('1.50x'), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);

      controller.add(2.0);
      await tester.pumpAndSettle();
      expect(find.text('2.00x'), findsOneWidget);

      await controller.close();
    });

    testWidgets('shows badge when rate < 1.0', (tester) async {
      final controller = StreamController<double>.broadcast();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeedIndicator(
            rateStream: controller.stream,
            currentRate: 0.5,
          ),
        ),
      ));

      expect(find.text('0.50x'), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);

      controller.add(0.25);
      await tester.pumpAndSettle();
      expect(find.text('0.25x'), findsOneWidget);

      await controller.close();
    });

    testWidgets('hides badge when rate is near 1.0', (tester) async {
      final controller = StreamController<double>.broadcast();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeedIndicator(
            rateStream: controller.stream,
            currentRate: 1.0,
          ),
        ),
      ));

      expect(find.text('1.00x'), findsNothing);
      expect(find.byIcon(Icons.speed), findsNothing);
      
      // Update with exact 1.0
      controller.add(1.0);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.speed), findsNothing);
      
      // Update with near 1.0
      controller.add(1.005);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.speed), findsNothing);

      await controller.close();
    });
  });
}
