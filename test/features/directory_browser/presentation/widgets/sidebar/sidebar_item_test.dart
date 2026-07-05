import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar_item.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('SidebarItem renders correctly when active and handles hover', (tester) async {
    var tapped = false;

    await tester.pumpWidget(buildTestWidget(
      SidebarItem(
        icon: Icons.home,
        label: 'Home',
        path: '/home/user',
        isActive: true,
        onTap: () {
          tapped = true;
        },
      ),
    ));

    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    
    // Tap the item
    await tester.tap(find.byType(SidebarItem));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    // Hover
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(SidebarItem)));
    await tester.pump();
    
    // Unhover
    await gesture.moveTo(const Offset(0, 0));
    await tester.pump();
    await gesture.removePointer();
  });

  testWidgets('SidebarItem renders correctly when inactive with progress', (tester) async {
    await tester.pumpWidget(buildTestWidget(
      SidebarItem(
        icon: Icons.storage,
        label: 'USB Drive',
        path: '/media/usb',
        isActive: false,
        progress: 0.5,
        storageText: '50% used',
        onTap: () {},
        onEject: () {},
      ),
    ));

    expect(find.text('USB Drive'), findsOneWidget);
    expect(find.text('50% used'), findsOneWidget);
    expect(find.byIcon(Icons.eject_outlined), findsOneWidget);
  });

}
