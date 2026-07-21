import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/marker_controller.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';

class MockPlayer extends Mock implements Player {}
class MockPlayerState extends Mock implements PlayerState {}
class MockMarkerActions extends Mock implements MarkerActions {}

void main() {
  group('VideoMarkerController', () {
    late MockPlayer mockPlayer;
    late MockPlayerState mockPlayerState;
    late MockMarkerActions mockMarkerActions;

    late bool mounted;
    late bool isMarkerEditorActive;
    late VideoMarker? editingMarker;
    late bool isControlsVisible;
    late Offset? markerEditorAnchor;
    late ValueNotifier<bool> isPlayingNotifier;
    late FocusNode focusNode;

    Timer? hideTimer;

    late bool onInteractionCalled;

    late VideoMarkerCallbacks callbacks;
    late VideoMarkerController controller;

    setUp(() {
      mockMarkerActions = MockMarkerActions();
      when(() => mockMarkerActions.addMarker(any(), any(), any(), icon: any(named: 'icon'))).thenAnswer((_) async {});
      when(() => mockMarkerActions.updateMarker(any(), any())).thenAnswer((_) async {});
    });

    Widget buildTestApp(WidgetTester tester, Function(WidgetRef) onBuild) {
      return ProviderScope(
        overrides: [
          markerActionsProvider.overrideWithValue(mockMarkerActions),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) {
                onBuild(ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    void setupController(WidgetRef ref) {
      mockPlayer = MockPlayer();
      mockPlayerState = MockPlayerState();
      when(() => mockPlayer.state).thenReturn(mockPlayerState);
      when(() => mockPlayerState.duration).thenReturn(const Duration(seconds: 100));
      when(() => mockPlayerState.position).thenReturn(const Duration(seconds: 50));
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      mounted = true;
      isMarkerEditorActive = false;
      editingMarker = null;
      isControlsVisible = false;
      markerEditorAnchor = null;
      isPlayingNotifier = ValueNotifier(false);
      focusNode = FocusNode();
      hideTimer = null;
      onInteractionCalled = false;

      callbacks = VideoMarkerCallbacks(
        getPlayer: () => mockPlayer,
        getRef: () => ref,
        getMounted: () => mounted,
        getIsMarkerEditorActive: () => isMarkerEditorActive,
        setIsMarkerEditorActive: (v) => isMarkerEditorActive = v,
        getEditingMarker: () => editingMarker,
        setEditingMarker: (v) => editingMarker = v,
        getIsControlsVisible: () => isControlsVisible,
        setIsControlsVisible: (v) => isControlsVisible = v,
        getMarkerEditorAnchor: () => markerEditorAnchor,
        setMarkerEditorAnchor: (v) => markerEditorAnchor = v,
        getSliderWidth: () => 800.0,
        getContextSize: () => const Size(1000, 800),
        getHideTimer: () => hideTimer,
        getIsPlayingNotifier: () => isPlayingNotifier,
        getFocusNode: () => focusNode,
        getCurrentVideoPath: () => '/path/to/video.mp4',
        onInteraction: () => onInteractionCalled = true,
        setStateCallback: (cb) => cb(),
      );

      controller = VideoMarkerController(callbacks);
    }

    setUpAll(() {
      registerFallbackValue(const Duration(seconds: 0));
      registerFallbackValue(VideoMarker(
        id: '1',
        timestamp: const Duration(seconds: 0),
        content: '',
      ));
    });

    testWidgets('openMarkerEditor without existing marker pauses and positions anchor', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      controller.openMarkerEditor();

      expect(isMarkerEditorActive, isTrue);
      expect(isControlsVisible, isTrue);
      expect(editingMarker, isNull);
      verify(() => mockPlayer.pause()).called(1);
      
      // 50s / 100s = 0.5 fraction. Width is 800. 0.5 * 800 = 400
      expect(markerEditorAnchor, equals(const Offset(400.0, 0)));
    });

    testWidgets('openMarkerEditor with existing marker uses marker timestamp', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      final marker = VideoMarker(id: '1', timestamp: const Duration(seconds: 25), content: 'Test');
      controller.openMarkerEditor(marker: marker);

      expect(editingMarker, equals(marker));
      
      // 25s / 100s = 0.25 fraction. Width is 800. 0.25 * 800 = 200
      expect(markerEditorAnchor, equals(const Offset(200.0, 0)));
    });

    testWidgets('saveMarker creates new marker when editingMarker is null', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      await controller.saveMarker('New Content', 'test-icon');

      verify(() => mockMarkerActions.addMarker(
        '/path/to/video.mp4',
        const Duration(seconds: 50),
        'New Content',
        icon: 'test-icon',
      )).called(1);

      expect(isMarkerEditorActive, isFalse);
    });

    testWidgets('saveMarker updates marker when editingMarker is not null', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      final marker = VideoMarker(id: '1', timestamp: const Duration(seconds: 25), content: 'Test');
      editingMarker = marker;

      await controller.saveMarker('Updated Content', 'updated-icon');

      verify(() => mockMarkerActions.updateMarker(
        '/path/to/video.mp4',
        marker.copyWith(content: 'Updated Content', icon: 'updated-icon'),
      )).called(1);

      expect(isMarkerEditorActive, isFalse);
    });

    testWidgets('closeMarkerEditor resets state and resumes if requested', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      isMarkerEditorActive = true;
      editingMarker = VideoMarker(id: '1', timestamp: const Duration(seconds: 0), content: '');
      markerEditorAnchor = const Offset(10, 10);

      controller.closeMarkerEditor(resume: true);

      expect(isMarkerEditorActive, isFalse);
      expect(editingMarker, isNull);
      expect(markerEditorAnchor, isNull);
      expect(onInteractionCalled, isTrue);
      expect(isPlayingNotifier.value, isTrue);
      verify(() => mockPlayer.play()).called(1);
    });
  });
}
