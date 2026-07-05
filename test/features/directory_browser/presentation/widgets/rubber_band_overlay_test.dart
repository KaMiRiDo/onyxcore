import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rubber_band_overlay.dart';

void main() {
  testWidgets('RubberBandOverlay builds successfully', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RubberBandOverlay(
              child: Container(
                width: 500,
                height: 500,
                color: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RubberBandOverlay), findsOneWidget);
  });
}
