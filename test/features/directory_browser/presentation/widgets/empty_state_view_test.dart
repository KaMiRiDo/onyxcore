import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/empty_state_view.dart';

void main() {
  testWidgets('EmptyStateView renders with custom messages and icon', (tester) async {
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
  });
}
