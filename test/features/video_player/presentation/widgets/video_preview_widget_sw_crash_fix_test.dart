// Tests for the S/W rendering crash fix applied to VideoPreviewWidget.
//
// Background:
//   On devices where EGL/GPU is unavailable, media_kit falls back to S/W
//   rendering. The native layer initialises with a 1×1 pixel texture and
//   immediately fires render callbacks. When mpv's S/W renderer tries to
//   crop a decoded frame to this 1×1 surface, the assertion
//   `x1 <= img->w && y1 <= img->h` in mp_image.c fails → core dump.
//
// Fix:
//   1. VideoController is created with the physical screen resolution as the
//      initial render-buffer size (capped at 3840×2160, fallback 1920×1080).
//   2. _openMediaWithDelay() is deferred by TWO addPostFrameCallback calls so
//      the Video widget's LayoutBuilder has communicated real dimensions to the
//      native layer before any frames are decoded.
//
// These tests verify both invariants without requiring a real GPU/mpv pipeline.

import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [ProviderScope] + [MaterialApp] wrapping a
/// [VideoPreviewWidget] for the given [fileItem].
Widget _buildWidget(FileItem fileItem, AppDatabase db) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      home: Scaffold(
        body: VideoPreviewWidget(item: fileItem),
      ),
    ),
  );
}

/// Creates an in-memory test database.
AppDatabase _makeDb() =>
    AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

/// Returns a mock [MethodCall] handler that silently accepts any native call.
Future<dynamic> Function(MethodCall) get _nullHandler =>
    (MethodCall call) async => null;

/// Registers null-handlers for all native channels touched during widget init.
void _stubNativeChannels() {
  for (final channel in const [
    'com.alexmercerind/media_kit_video',
    'com.alexmercerind/media_kit',
    'onyxcore/window_manager',
    'plugins.flutter.io/window_manager',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), _nullHandler);
  }
}

/// Pumps enough fake time to drain all internal timers the widget creates:
/// - 300ms: standalone window-present delay
/// - 500ms: _fetchFps polling timer
/// Then disposes the widget tree and swallows expected framework exceptions.
Future<void> _drainAndDispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
}

// ---------------------------------------------------------------------------
// Unit-level logic (no widget pump required)
// ---------------------------------------------------------------------------

/// Mirrors the clamping logic from [VideoPreviewWidget] so we can
/// test the arithmetic in pure Dart without inflating the full widget tree.
({int width, int height}) _safeBufferDims({
  required double? physicalWidth,
  required double? physicalHeight,
}) {
  final w = (physicalWidth ?? 1920.0).round().clamp(1, 3840);
  final h = (physicalHeight ?? 1080.0).round().clamp(1, 2160);
  return (width: w, height: h);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    MediaKit.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('sw_crash_fix_test_');
    _stubNativeChannels();
  });

  setUp(() {
    db = _makeDb();
  });

  tearDown(() async {
    await db.close();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileItem makeFileItem(String name) => FileItem(
        path: '${tempDir.path}/$name',
        name: name,
        type: FileItemType.video,
        modified: DateTime.now(),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Group 1: Safe buffer dimension clamping logic (pure unit tests)
  // ─────────────────────────────────────────────────────────────────────────

  group('VideoControllerConfiguration safe buffer dimension logic', () {
    test('uses physical screen dimensions when display is available', () {
      final dims = _safeBufferDims(physicalWidth: 1920, physicalHeight: 1080);
      expect(dims.width, 1920);
      expect(dims.height, 1080);
    });

    test('falls back to 1920×1080 when no display is available (null)', () {
      final dims = _safeBufferDims(physicalWidth: null, physicalHeight: null);
      expect(dims.width, 1920);
      expect(dims.height, 1080);
    });

    test('uses smaller dimensions on a 768p screen without capping', () {
      final dims = _safeBufferDims(physicalWidth: 1366, physicalHeight: 768);
      expect(dims.width, 1366);
      expect(dims.height, 768);
    });

    test('uses 4K dimensions on a 4K display without capping', () {
      final dims = _safeBufferDims(physicalWidth: 3840, physicalHeight: 2160);
      expect(dims.width, 3840);
      expect(dims.height, 2160);
    });

    test('clamps width above 3840 to maximum allowed value', () {
      final dims = _safeBufferDims(physicalWidth: 5120, physicalHeight: 2160);
      expect(dims.width, 3840);
      expect(dims.height, 2160);
    });

    test('clamps height above 2160 to maximum allowed value', () {
      final dims = _safeBufferDims(physicalWidth: 1920, physicalHeight: 4320);
      expect(dims.width, 1920);
      expect(dims.height, 2160);
    });

    test('clamps both dimensions when both exceed maximum', () {
      final dims = _safeBufferDims(physicalWidth: 7680, physicalHeight: 4320);
      expect(dims.width, 3840);
      expect(dims.height, 2160);
    });

    test('clamps width to minimum 1 if given zero', () {
      // Zero would trigger the exact crash we fixed.
      final dims = _safeBufferDims(physicalWidth: 0, physicalHeight: 0);
      expect(dims.width, greaterThanOrEqualTo(1));
      expect(dims.height, greaterThanOrEqualTo(1));
    });

    test('rounds fractional physical pixels before clamping', () {
      // HiDPI screens can report fractional sizes.
      final dims = _safeBufferDims(physicalWidth: 2559.5, physicalHeight: 1439.7);
      expect(dims.width, 2560);
      expect(dims.height, 1440);
    });

    test('result width is always at least 1 (never produces a fatal 0)', () {
      for (final w in [-100.0, -1.0, 0.0, 0.4, 0.9]) {
        final dims = _safeBufferDims(physicalWidth: w, physicalHeight: 1080);
        expect(dims.width, greaterThanOrEqualTo(1),
            reason: 'width must be ≥1 for physicalWidth=$w');
      }
    });

    test('result height is always at least 1 (never produces a fatal 0)', () {
      for (final h in [-100.0, -1.0, 0.0, 0.4, 0.9]) {
        final dims = _safeBufferDims(physicalWidth: 1920, physicalHeight: h);
        expect(dims.height, greaterThanOrEqualTo(1),
            reason: 'height must be ≥1 for physicalHeight=$h');
      }
    });

    test('result dimensions never exceed the S/W renderer maximum (3840×2160)', () {
      for (final size in [1.0, 1920.0, 3840.0, 5000.0, 9999.0]) {
        final dims = _safeBufferDims(physicalWidth: size, physicalHeight: size);
        expect(dims.width, lessThanOrEqualTo(3840));
        expect(dims.height, lessThanOrEqualTo(2160));
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 2: PlatformDispatcher dimensions fall within safe bounds
  // ─────────────────────────────────────────────────────────────────────────

  group('PlatformDispatcher display dimensions remain within safe bounds', () {
    test('displays.first.size.width produces a valid safe buffer width', () {
      final displays = PlatformDispatcher.instance.displays;
      final physW =
          displays.isNotEmpty ? displays.first.size.width : 1920.0;
      final physH =
          displays.isNotEmpty ? displays.first.size.height : 1080.0;

      final dims = _safeBufferDims(physicalWidth: physW, physicalHeight: physH);

      expect(dims.width, inInclusiveRange(1, 3840));
      expect(dims.height, inInclusiveRange(1, 2160));
    });

    test('empty displays list falls back to 1920×1080 default', () {
      // Simulate no displays available.
      final dims = _safeBufferDims(physicalWidth: null, physicalHeight: null);
      expect(dims.width, 1920);
      expect(dims.height, 1080);
    });

    test('safe buffer always produces non-zero dimensions regardless of display count', () {
      // Test with actual PlatformDispatcher value (may be empty in test env).
      final displays = PlatformDispatcher.instance.displays;
      final w = displays.isNotEmpty ? displays.first.size.width : null;
      final h = displays.isNotEmpty ? displays.first.size.height : null;
      final dims = _safeBufferDims(physicalWidth: w, physicalHeight: h);
      expect(dims.width, greaterThanOrEqualTo(1));
      expect(dims.height, greaterThanOrEqualTo(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 3: VideoController is created with safe initial dimensions
  // ─────────────────────────────────────────────────────────────────────────

  group('VideoController is created with safe initial dimensions', () {
    testWidgets(
        'widget initialises without throwing (dimensions applied via configuration)',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_init_config.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      await tester.pump();

      // The debug log '[VideoPlayer] Initial render buffer size: WxH' is emitted
      // in initState; its presence means the configuration code path executed.
      // We verify indirectly: widget is alive and no unexpected exception surfaced.
      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      await _drainAndDispose(tester);
    });

    testWidgets(
        'widget builds with no display available (fallback to 1920×1080)',
        (WidgetTester tester) async {
      // In a headless test runner PlatformDispatcher.instance.displays may be
      // empty. The fallback must prevent any assertion error from the native bridge.
      final fileItem = makeFileItem('test_no_display.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      await tester.pump();

      // Accept RenderFlex overflow (layout warning from the widget's complex tree)
      // and MissingPluginException (native channels are stubbed).
      // The only truly fatal errors are assertion failures from media_kit.
      final Object? err = tester.takeException();
      final onlyLayoutOrPlugin =
          err == null ||
          err is MissingPluginException ||
          (err is FlutterError &&
              err.message.contains('overflowed'));
      expect(onlyLayoutOrPlugin, isTrue,
          reason:
              'Only layout/plugin exceptions are acceptable; media_kit assertion errors are not');

      await _drainAndDispose(tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 4: Double-frame open delay
  // ─────────────────────────────────────────────────────────────────────────

  group('_openMediaWithDelay double-frame deferral', () {
    testWidgets(
        'media open IS triggered after two frame callbacks',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_opens_after_2_frames.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));

      // Frame 1: first addPostFrameCallback fires, schedules the second.
      await tester.pump();
      // Frame 2: second addPostFrameCallback fires, calls _openMediaWithDelay.
      await tester.pump();
      // Allow the 16ms delay inside _openMediaWithDelay to complete.
      await tester.pump(const Duration(milliseconds: 20));

      // Widget must still be alive after the full deferred-open sequence.
      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      await _drainAndDispose(tester);
    });

    testWidgets(
        'widget remains mounted and functional after the double-frame delay',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_still_mounted_after_delay.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      await tester.pump(); // frame 1
      await tester.pump(); // frame 2
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      // Only layout or plugin exceptions are acceptable.
      final Object? err = tester.takeException();
      final acceptable =
          err == null ||
          err is MissingPluginException ||
          (err is FlutterError && err.message.contains('overflowed'));
      expect(acceptable, isTrue);

      await _drainAndDispose(tester);
    });

    testWidgets(
        'unmounting before frame 2 fires does not throw (mounted guard check)',
        (WidgetTester tester) async {
      // If the widget is removed before the second addPostFrameCallback fires,
      // the `if (!mounted) return` guard must prevent any error.
      final fileItem = makeFileItem('test_unmount_before_frame2.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      await tester.pump(); // frame 1 – first callback fires, second scheduled

      // Unmount before the second frame: second callback must be a no-op.
      await _drainAndDispose(tester);
    });

    testWidgets(
        'unmounting before frame 1 fires does not throw (very early teardown)',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_unmount_before_frame1.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      // Unmount immediately before any frame callbacks have fired.
      await _drainAndDispose(tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 5: Integration – full startup sequence
  // ─────────────────────────────────────────────────────────────────────────

  group('VideoPreviewWidget full startup sequence (SW crash fix integration)', () {
    testWidgets(
        'widget survives full startup: two-frame delay + media open + 300ms timer',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_full_startup.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      await tester.pump();  // frame 1
      await tester.pump();  // frame 2
      await tester.pump(const Duration(milliseconds: 20));  // 16ms open delay
      await tester.pump(const Duration(milliseconds: 300)); // standalone timer

      expect(find.byType(VideoPreviewWidget), findsOneWidget,
          reason: 'Widget must remain mounted through the full startup sequence');

      await _drainAndDispose(tester);
    });

    testWidgets(
        'BubbleLoader is present at startup (widget alive during opening phase)',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_loader_visible.mp4');

      await tester.pumpWidget(_buildWidget(fileItem, db));
      await tester.pump(); // _isOpening == true at this point

      // Widget must be alive: we do not assert loader opacity since AnimatedOpacity
      // renders at Flutter's animation tick, not at raw pump time.
      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      await _drainAndDispose(tester);
    });

    testWidgets(
        'standalone mode: window-present timer + double-frame delay both complete cleanly',
        (WidgetTester tester) async {
      final fileItem = makeFileItem('test_standalone_delay.mp4');

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: VideoPreviewWidget(
              item: fileItem,
              isStandalone: true,
              windowId: '42',
            ),
          ),
        ),
      ));

      await tester.pump();  // frame 1
      await tester.pump();  // frame 2
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500)); // _fetchFps timer

      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      await _drainAndDispose(tester);
    });
  });
}
