import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/empty_state_view.dart';

void main() {
  testWidgets('EmptyStateView renders with custom messages and icon without action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateView(
            title: 'No files found',
            subtitle: 'Try another search',
            icon: Icons.search_off,
          ),
        ),
      ),
    );

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('No files found'), findsOneWidget);
    expect(find.text('Try another search'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('EmptyStateView renders with custom messages, icon and triggers action', (tester) async {
    var actionTriggered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateView(
            title: 'No files found',
            subtitle: 'Try another search',
            icon: Icons.search_off,
            actionLabel: 'Click Me',
            onAction: () {
              actionTriggered = true;
            },
          ),
        ),
      ),
    );

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('Click Me'), findsOneWidget);
    
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    
    expect(actionTriggered, isTrue);
  });
}
