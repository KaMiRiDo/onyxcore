// ignore_for_file: avoid_dynamic_calls
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:path/path.dart' as p;

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository(this.initialItems);
  final List<FileItem> initialItems;
  List<String>? deletedPaths;

  @override
  void invalidateCache(String path, {bool recursive = false}) {}

  @override
  Stream<FileChangeEvent> watchDirectory(String path) => const Stream.empty();

  @override
  Future<List<FileItem>> listDirectory(String path) async => initialItems;

  @override
  Future<void> moveToTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {
    deletedPaths = paths;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeImageFavoritesNotifier extends ImageFavoritesNotifier {
  @override
  void setRef(Ref ref) {
    // No-op
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late String pngPath;
  late String heicPath;
  late String svgPath;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_preview_test_');
    final resourcesDir = Directory('test/features/image_viewer/resources');

    pngPath = p.join(resourcesDir.path, 'test_image.png');
    heicPath = p.join(resourcesDir.path, 'test_image.heic');
    svgPath = p.join(resourcesDir.path, 'test_image.svg');

    File(pngPath).copySync(p.join(tempDir.path, 'test_image.png'));
    File(heicPath).copySync(p.join(tempDir.path, 'test_image.heic'));
    File(svgPath).copySync(p.join(tempDir.path, 'test_image.svg'));
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ImagePreviewWidget', () {
    late FileItem dummyPng;
    late FileItem dummyHeic;
    late FileItem dummySvg;

    setUp(() {
      dummyPng = FileItem(
        path: p.join(tempDir.path, 'test_image.png'),
        name: 'test_image.png',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      dummyHeic = FileItem(
        path: p.join(tempDir.path, 'test_image.heic'),
        name: 'test_image.heic',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      dummySvg = FileItem(
        path: p.join(tempDir.path, 'test_image.svg'),
        name: 'test_image.svg',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      PersistentViewerManager.reset();
    });

    Future<void> setupMethodChannels(List<MethodCall> logs) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('onyxcore/window_manager'),
            (MethodCall methodCall) async {
              logs.add(methodCall);
              if (methodCall.method == 'create_window') {
                return 400;
              }
              return null;
            },
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            logs.add(methodCall);
            return null;
          });
    }

    testWidgets('loads and displays standard image metadata', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith(
                (ref) => FakeImageFavoritesNotifier(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
            ),
          ),
        );
        // The first frame should show a BubbleLoader while the image is decoding
        expect(
          find.byType(BubbleLoader),
          findsOneWidget,
          reason: 'Should show loader during image decode',
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImagePreviewWidget), findsOneWidget);
      // After settling, the loader should be gone
      expect(
        find.byType(BubbleLoader),
        findsNothing,
        reason: 'Loader should disappear after image is loaded',
      );

      // Verify that the image is rendered correctly
      final imageWidget = tester.widget<Image>(find.byType(Image).last);
      final imageProvider = imageWidget.image;
      expect(imageProvider, isA<FileImage>());
    });

    testWidgets('loads and displays SVG metadata', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith(
                (ref) => FakeImageFavoritesNotifier(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummySvg)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImagePreviewWidget), findsOneWidget);
    });

    testWidgets('handles special image fallback properly (HEIC)', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith(
                (ref) => FakeImageFavoritesNotifier(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyHeic)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.byType(ImagePreviewWidget), findsOneWidget);
    });

    testWidgets('updates image path in providers when standalone is true', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          imageShowHiddenProvider.overrideWith((ref) => false),
          imageFavoritesProvider.overrideWith(
            (ref) => FakeImageFavoritesNotifier(),
          ),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(item: dummyPng, isStandalone: true),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(container.read(imageCurrentPathProvider), tempDir.path);
    });

    testWidgets('loads standalone playlist from initParams', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          imageShowHiddenProvider.overrideWith((ref) => false),
          imageFavoritesProvider.overrideWith(
            (ref) => FakeImageFavoritesNotifier(),
          ),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: dummyPng,
                  isStandalone: true,
                  initParams: {
                    'playlistPaths': [
                      dummyPng.path,
                      dummyHeic.path,
                      'invalid_path.jpg',
                    ],
                  },
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      final queue = container.read(imageQueueProvider);
      expect(queue.length, 2);
      expect(queue[0].path, dummyPng.path);
      expect(queue[1].path, dummyHeic.path);
    });

    testWidgets('closes preview on Backspace in inline mode', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          previewFileProvider.overrideWith((ref) => dummyPng),
          imageShowHiddenProvider.overrideWith((ref) => false),
          imageFavoritesProvider.overrideWith(
            (ref) => FakeImageFavoritesNotifier(),
          ),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(container.read(previewFileProvider), isNull);
    });

    testWidgets('requests focus and triggers presentWindow when standalone', (
      WidgetTester tester,
    ) async {
      final logs = <MethodCall>[];
      await setupMethodChannels(logs);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith(
                (ref) => FakeImageFavoritesNotifier(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: dummyPng,
                  isStandalone: true,
                  windowId: '400',
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(
        logs,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'present_window')
              .having((call) => call.arguments['view_id'], 'view_id', 400),
        ),
      );
    });

    testWidgets('tests all keyboard shortcuts and pointer events', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final logs = <MethodCall>[];
      await setupMethodChannels(logs);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith(
                (ref) => FakeImageFavoritesNotifier(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      // Test Keyboard Shortcuts
      final keys = [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.f11,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.keyF,
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.keyC, // copy
      ];

      for (final key in keys) {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
      }

      // Test Toolbar buttons (wrap inside runAsync if they invoke native code like copy)
      final iconsToTap = [
        Icons.info_outline,
        Icons.share,
        Icons.copy,
        Icons.wallpaper,
        Icons.print,
        Icons.rotate_right,
        Icons.pin_invoke,
      ];

      for (final icon in iconsToTap) {
        final btn = find.byIcon(icon);
        if (btn.evaluate().isNotEmpty) {
          await tester.tap(btn.first);
          await tester.pumpAndSettle();

          if (find.byType(Dialog).evaluate().isNotEmpty ||
              find.byType(AlertDialog).evaluate().isNotEmpty) {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }
        }
      }
    });

    testWidgets('tests gestures (zoom and pan)', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith(
                (ref) => FakeImageFavoritesNotifier(),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(item: dummyPng, isStandalone: true),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      final viewer = find.byType(InteractiveViewer);
      expect(viewer, findsOneWidget);

      final center = tester.getCenter(viewer);

      // Double tap to zoom in
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      // Pan
      await tester.drag(viewer, const Offset(50, 50));
      await tester.pumpAndSettle();

      // Double tap to zoom out
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'tests explicit zoom logic (keyboard, mouse scroll, pinch gesture)',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            imageShowHiddenProvider.overrideWith((ref) => false),
            imageFavoritesProvider.overrideWith(
              (ref) => FakeImageFavoritesNotifier(),
            ),
          ],
        );

        await tester.runAsync(() async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(seconds: 1));
        });
        await tester.pumpAndSettle();

        final viewer = find.byType(InteractiveViewer);
        expect(viewer, findsOneWidget);

        final center = tester.getCenter(viewer);

        // 1. Zoom with Ctrl + Scroll (Mouse Scroll)
        // Simulating a pointer signal for scrolling
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: center);
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

        // We simulate a scroll event. flutter_test has sendEventToBinding for PointerScrollEvent
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -100), // Scroll up to zoom in
          ),
        );
        await tester.pumpAndSettle();

        // 2. Zoom with keyboard shortcuts (Ctrl + Equal, Ctrl + Minus, Ctrl + 0)
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.minus);
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
        await tester.pumpAndSettle();

        // 3. Pinch-to-zoom simulation (Ctrl + Drag triggers _setZoomFromGesture)
        await tester.drag(viewer, const Offset(0, 100));
        await tester.pumpAndSettle();

        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        // 4. Test sidebar offset logic
        container.read(imagePlaylistSidebarVisibleProvider.notifier).state =
            true;
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.equal);
        await tester.pumpAndSettle();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      },
    );

    testWidgets('Disabled Edit Button Regression Test', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
        ],
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      final editIcon = find.byIcon(Icons.edit_outlined);
      expect(editIcon, findsOneWidget);
      
      final buttonFinder = find.ancestor(of: editIcon, matching: find.byType(IconButton));
      final buttonWidget = tester.widget<IconButton>(buttonFinder);
      expect(buttonWidget.onPressed, isNull); // Edit button is disabled
    });

    testWidgets('Zoom → Pan Real-Image Regression Test', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
        ],
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      // Ensure ImageCanvas is mounted
      expect(find.byType(Image), findsWidgets);
      
      // Zoom
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(InteractiveViewer)),
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
      
      // Scrub/Pan immediately
      final gesture = await tester.startGesture(tester.getCenter(find.byType(InteractiveViewer)));
      await gesture.moveBy(const Offset(50, 50));
      await tester.pump();
      
      // Verify image is still rendered
      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
      
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    });

    testWidgets('High-Resolution Promotion and Cancellation Test', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
        ],
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: dummyPng)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();
      
      expect(find.byType(Image), findsWidgets);

      // Start interaction (pan)
      final viewer = find.byType(InteractiveViewer);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(viewer),
          scrollDelta: const Offset(0, -100), // Zoom in so we can pan
        ),
      );
      await tester.pump(); // Zoom ticks
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      
      final gesture = await tester.startGesture(tester.getCenter(viewer));
      await tester.pump(); // Starts interaction
      
      // During active interaction, highRes image is hidden.
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 100)); // Advance time during interaction
      
      // Still interacting -> no promotion
      await gesture.moveBy(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 250)); // Advance time again, > 300ms total
      
      // Still interacting, timer should have been cancelled, so no promotion
      expect(tester.takeException(), isNull);
      
      // Assert actual render state during active interaction
      final activeImages = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(activeImages.length, 1, reason: 'Only low-res image should be visible during interaction');
      expect(activeImages.first.filterQuality, FilterQuality.low, reason: 'Quality must be low during interaction');
      
      // End interaction
      await gesture.up();
      await tester.pump();
      
      // Right after interaction ends, the interaction notifier is in "settling" phase (200ms delay)
      // So highRes is still hidden (1 Image), and quality is still low.
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, 1, reason: 'High-res image should not be promoted yet');
      expect(images.first.filterQuality, FilterQuality.low);
      
      // Wait for 100ms (not fully settled, which is 200ms)
      await tester.pump(const Duration(milliseconds: 100));
      
      // Start another interaction before settle
      final gesture2 = await tester.startGesture(tester.getCenter(viewer));
      await tester.pump();
      
      // Wait > 300ms, should STILL not promote
      await tester.pump(const Duration(milliseconds: 350));
      
      // End final interaction
      await gesture2.up();
      await tester.pump();
      
      // Now fully settle (> 300ms since last interaction ended)
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      
      // Should have successfully promoted without errors
      expect(tester.takeException(), isNull);
      
      // Assert actual render state after settling
      final finalImages = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(finalImages.length, 2, reason: 'Both low-res and high-res images should be rendered after promotion');
      expect(finalImages.last.filterQuality, FilterQuality.high, reason: 'High-res image should have high quality');
    });




    testWidgets('top bar title, metadata, and standalone differences', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageQueueProvider.overrideWith((ref) => [dummyPng]),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
            ],
            child: MaterialApp(home: Scaffold(body: ImagePreviewWidget(item: dummyPng, isStandalone: true))),
          ),
        );
        // wait for initialization finish
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      // Show HUD by interacting
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // wait for fade in

      // Title should be visible
      expect(find.text('test_image.png'), findsOneWidget);

      // Metadata string should be visible (e.g. "1/3" or "2/3")
      expect(find.byWidgetPredicate((widget) => widget is Text && widget.data != null && RegExp(r'\d+/\d+').hasMatch(widget.data!)), findsOneWidget);

      // Popout/close buttons are hidden in standalone mode
      expect(find.byTooltip('Pop Out'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
    });

    testWidgets('network stream mode hides edit/favorite and disables playlist button', (tester) async {
      final streamItem = FileItem(
        path: 'http://example.com/stream.jpg',
        name: 'stream.jpg',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      final container = ProviderContainer(
        overrides: [
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
        ],
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: Scaffold(body: ImagePreviewWidget(item: streamItem, isStandalone: true, initParams: const {'is_network_stream': true}))),
          ),
        );
        // wait for initialization
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();
      tester.takeException(); // consume NetworkImageLoadException

      // Show HUD
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // wait for fade in

      // Edit and Favorite should be hidden for network streams
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      // Playlist button is disabled (its onPressed is null)
      final playlistBtnIcon = find.byIcon(Icons.playlist_play);
      expect(playlistBtnIcon, findsOneWidget);
      final playlistBtn = tester.widget<IconButton>(find.ancestor(of: playlistBtnIcon, matching: find.byType(IconButton)).first);
      expect(playlistBtn.onPressed, isNull);
    });

    testWidgets('didUpdateWidget loads new image when path changes', (tester) async {
      final img1 = dummyPng;
      final img2 = dummyHeic;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: img1)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.text('test_image.png'), findsWidgets);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(body: ImagePreviewWidget(item: img2)),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      expect(find.text('test_image.heic'), findsWidgets);
    });

    testWidgets('responds to on_window_focus channel event by requesting focus', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: dummyPng,
                  isStandalone: true,
                  windowId: '400',
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      final focusNodeFinder = find.byType(Focus);
      expect(focusNodeFinder, findsWidgets);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'onyxcore/window_manager',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('on_window_focus', {'view_id': 400}),
            ),
            (data) {},
          );
      await tester.pumpAndSettle();
    });

    testWidgets('handles interaction delta and focal point calculation with sidebar open', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageShowHiddenProvider.overrideWith((ref) => false),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(item: dummyPng),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      container.read(imagePlaylistSidebarVisibleProvider.notifier).state = true;
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();

      await tester.sendEventToBinding(
        const PointerHoverEvent(
          position: Offset(10, 10),
        ),
      );
      await tester.pump();
      
      await gesture.removePointer();
    });

    testWidgets('toggles fullscreen in standalone window mode via F11', (tester) async {
      final logs = <MethodCall>[];
      await setupMethodChannels(logs);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: dummyPng,
                  isStandalone: true,
                  windowId: '400',
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();

      expect(
        logs,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'set_fullscreen')
              .having((call) => call.arguments['view_id'], 'view_id', 400)
              .having((call) => call.arguments['is_fullscreen'], 'is_fullscreen', true),
        ),
      );
    });

    testWidgets('pops out image in a new window and clears inline navigation', (tester) async {
      final logs = <MethodCall>[];
      await setupMethodChannels(logs);

      final container = ProviderContainer(
        overrides: [
          previewFileProvider.overrideWith((ref) => dummyPng),
          imageShowHiddenProvider.overrideWith((ref) => false),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(item: dummyPng),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final popOutBtn = find.byTooltip('Pop Out');
      expect(popOutBtn, findsOneWidget);
      await tester.tap(popOutBtn);
      await tester.pumpAndSettle();

      expect(
        logs,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'create_window'),
        ),
      );

      expect(container.read(previewFileProvider), isNull);
    });

    testWidgets('handles window close channel event', (tester) async {
      final logs = <MethodCall>[];
      await setupMethodChannels(logs);
      PersistentViewerManager.init();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: dummyPng,
                  isStandalone: true,
                  windowId: '400',
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'onyxcore/window_manager',
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall('on_window_close', {'view_id': 400}),
              ),
              (data) {},
            );
        await Future<void>.delayed(const Duration(milliseconds: 1800));
      });

      expect(
        logs,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'close_window')
              .having((call) => call.arguments['view_id'], 'view_id', 400),
        ),
      );
    });

    testWidgets('handles deletion with confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeDirectoryRepository([dummyPng]);

      final container = ProviderContainer(
        overrides: [
          previewFileProvider.overrideWith((ref) => dummyPng),
          imageShowHiddenProvider.overrideWith((ref) => false),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          directoryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(item: dummyPng),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(find.byType(ViewerDeleteDialog), findsOneWidget);

      await tester.tap(find.text('Yes, Trash'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
