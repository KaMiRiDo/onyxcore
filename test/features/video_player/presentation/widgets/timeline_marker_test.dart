import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/timeline_marker.dart';

class MockMarkerActions implements MarkerActions {
  bool deletedAll = false;
  String? deletedMarkerId;

  @override
  Future<void> deleteAllMarkers(String videoPath) async {
    deletedAll = true;
  }

  @override
  Future<void> deleteMarker(String videoPath, String markerId) async {
    deletedMarkerId = markerId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('TimelineMarker renders emoji marker and handles hover', (WidgetTester tester) async {
    const marker = VideoMarker(
      id: '1',
      timestamp: Duration(seconds: 5),
      content: 'Test Marker',
    );
    final hoverXNotifier = ValueNotifier<double?>(null);
    var hoverState = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TimelineMarker(
                  marker: marker,
                  totalDuration: const Duration(seconds: 10),
                  sliderWidth: 300,
                  videoPath: 'test.mp4',
                  onTap: () {},
                  onEdit: () {},
                  onHoverChanged: (val) {
                    hoverState = val;
                  },
                  onMenuVisibilityChanged: (_) {},
                  hoverXNotifier: hoverXNotifier,
                  isMarkerEditorActive: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('📍'), findsOneWidget);
    expect(find.text('Test Marker'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('📍')));
    await tester.pump();

    expect(find.text('Test Marker'), findsOneWidget);
    expect(hoverState, true);

    await tester.tap(find.text('📍'));
    await tester.pump();
  });

  testWidgets('TimelineMarker handles base64 image icon', (WidgetTester tester) async {
    // 1x1 transparent PNG base64
    const b64 = 'B64:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    const marker = VideoMarker(
      id: '1',
      timestamp: Duration(seconds: 5),
      icon: b64,
      content: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TimelineMarker(
                  marker: marker,
                  totalDuration: const Duration(seconds: 10),
                  sliderWidth: 300,
                  videoPath: 'test.mp4',
                  onTap: () {},
                  onEdit: () {},
                  onHoverChanged: (_) {},
                  onMenuVisibilityChanged: (_) {},
                  hoverXNotifier: ValueNotifier<double?>(null),
                  isMarkerEditorActive: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // It should render an Image for a valid base64 icon
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('TimelineMarker handles invalid base64 gracefully', (WidgetTester tester) async {
    const marker = VideoMarker(
      id: '1',
      timestamp: Duration(seconds: 5),
      icon: 'B64:INVALID_BASE64_!!!!',
      content: '',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TimelineMarker(
                  marker: marker,
                  totalDuration: const Duration(seconds: 10),
                  sliderWidth: 300,
                  videoPath: 'test.mp4',
                  onTap: () {},
                  onEdit: () {},
                  onHoverChanged: (_) {},
                  onMenuVisibilityChanged: (_) {},
                  hoverXNotifier: ValueNotifier<double?>(null),
                  isMarkerEditorActive: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Because it failed to decode, it falls back or skips image
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('TimelineMarker shows radial menu, clicks edit, delete, and delete all', (WidgetTester tester) async {
    const marker = VideoMarker(
      id: '1',
      timestamp: Duration(seconds: 5),
      content: 'Test Marker',
    );
    
    var editCalled = false;
    final mockActions = MockMarkerActions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          markerActionsProvider.overrideWithValue(mockActions),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: Stack(
                children: [
                  TimelineMarker(
                    marker: marker,
                    totalDuration: const Duration(seconds: 10),
                    sliderWidth: 300,
                    videoPath: 'test.mp4',
                    onTap: () {},
                    onEdit: () { editCalled = true; },
                    onHoverChanged: (_) {},
                    onMenuVisibilityChanged: (_) {},
                    hoverXNotifier: ValueNotifier<double?>(null),
                    isMarkerEditorActive: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 1. Test Edit
    var gesture = await tester.startGesture(tester.getCenter(find.text('📍')), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    expect(editCalled, true);

    // 2. Test Delete Single
    gesture = await tester.startGesture(tester.getCenter(find.text('📍')), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();
    
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(mockActions.deletedMarkerId, '1');

    // 3. Test Delete All (Cancel)
    gesture = await tester.startGesture(tester.getCenter(find.text('📍')), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();
    
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    
    // Shows dialog
    expect(find.text('Delete all markers?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(mockActions.deletedAll, false);

    // 4. Test Delete All (Confirm)
    gesture = await tester.startGesture(tester.getCenter(find.text('📍')), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();
    
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    
    expect(find.text('Delete all markers?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(mockActions.deletedAll, true);
  });

  testWidgets('TimelineMarker closes menu when isMarkerEditorActive changes to true', (WidgetTester tester) async {
    const marker = VideoMarker(id: '1', timestamp: Duration(seconds: 5), content: 'Test');
    
    final valueNotifier = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: valueNotifier,
              builder: (context, isActive, _) {
                return Stack(
                  children: [
                    TimelineMarker(
                      marker: marker,
                      totalDuration: const Duration(seconds: 10),
                      sliderWidth: 300,
                      videoPath: 'test.mp4',
                      onTap: () {},
                      onEdit: () {},
                      onHoverChanged: (_) {},
                      onMenuVisibilityChanged: (_) {},
                      hoverXNotifier: ValueNotifier<double?>(null),
                      isMarkerEditorActive: isActive,
                    ),
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );

    // Open menu
    final gesture = await tester.startGesture(tester.getCenter(find.text('📍')), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    // Trigger update
    valueNotifier.value = true;
    await tester.pumpAndSettle();
    
    // Menu should be closed
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
  });
}
