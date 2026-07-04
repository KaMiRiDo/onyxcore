import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';

void main() {
  testWidgets('ContextMenu renders items and handles taps', (tester) async {
    bool wasTapped = false;
    final items = [
      ContextMenuItem(
        title: 'Copy',
        icon: Icons.copy,
        onTap: () {
          wasTapped = true;
        },
        shortcut: 'Ctrl+C',
      ),
      ContextMenuItem.divider(),
      ContextMenuItem(
        title: 'Delete',
        icon: Icons.delete,
        isDestructive: true,
        onTap: () {},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ContextMenu.show(context, const Offset(100, 100), items);
              },
              child: const Text('Show Menu'),
            ),
          ),
        ),
      ),
    );

    // Tap to show menu
    await tester.tap(find.text('Show Menu'));
    await tester.pumpAndSettle();

    // Verify items
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Ctrl+C'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);

    // Tap 'Copy'
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(wasTapped, true);
    
    // Menu should be closed
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('ContextMenu submenu logic works', (tester) async {
    final items = [
      ContextMenuItem(
        title: 'New',
        onTap: () {},
        subItems: [
          ContextMenuItem(
            title: 'Folder',
            onTap: () {},
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ContextMenu.show(context, const Offset(100, 100), items);
              },
              child: const Text('Show Menu'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Menu'));
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);

    // Hover over 'New'
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('New')));
    await tester.pumpAndSettle();
    
    // Submenu delay
    await tester.pump(const Duration(milliseconds: 300));
    
    // Submenu item should be visible
    expect(find.text('Folder'), findsOneWidget);
  });

  testWidgets('ContextMenu hides when tapping outside', (tester) async {
    final items = [
      ContextMenuItem(
        title: 'Copy',
        onTap: () {},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ContextMenu.show(context, const Offset(100, 100), items);
              },
              child: const Text('Show Menu'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);

    // Tap outside menu (tap at top left corner)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Menu should be closed
    expect(find.text('Copy'), findsNothing);
  });
}
