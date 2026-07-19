import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/menu_tooltip.dart';

void main() {
  testWidgets('MenuTooltip shows and hides message on hover', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MenuTooltip(
              message: 'Test Tooltip',
              child: Text('Hover Me'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hover Me'), findsOneWidget);
    expect(find.text('Test Tooltip'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('Hover Me')));
    await tester.pump();

    expect(find.text('Test Tooltip'), findsOneWidget);

    await gesture.moveTo(Offset.zero);
    await tester.pump();

    expect(find.text('Test Tooltip'), findsNothing);
  });

  testWidgets('MenuTooltip handles long text gracefully', (WidgetTester tester) async {
    const longText = 'This is a very very very long tooltip message that should be truncated by maxLines: 1';
    
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MenuTooltip(
              message: longText,
              child: Text('Hover Me'),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('Hover Me')));
    await tester.pump();

    final textWidget = tester.widget<Text>(find.text(longText));
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
}
