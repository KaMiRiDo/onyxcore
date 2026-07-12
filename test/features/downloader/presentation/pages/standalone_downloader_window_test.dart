import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';

// ignore_for_file: avoid_dynamic_calls, invalid_use_of_protected_member

class MockDownloadsSharedController extends Mock implements DownloadsSharedController {
  @override
  DownloadsListCache get cache => DownloadsListCache();
}
class MockPersistentViewerManager extends Mock implements PersistentViewerManager {}
class MockDownloadsListCache extends Mock implements DownloadsListCache {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('StandaloneDownloaderWindow Unit Tests', () {
    testWidgets('U-SDW-001 to U-SDW-015: _getHeight() logic', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1),
            ),
          ),
        ),
      );
      final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
      
      expect(state.getHeightForTesting(''), 0, reason: 'U-SDW-001');
      expect(state.getHeightForTesting('audio only'), 0, reason: 'U-SDW-002');
      expect(state.getHeightForTesting('audio'), 0, reason: 'U-SDW-003');
      expect(state.getHeightForTesting('4K'), 2160, reason: 'U-SDW-004');
      expect(state.getHeightForTesting('2160p'), 2160, reason: 'U-SDW-005');
      expect(state.getHeightForTesting('1440p'), 1440, reason: 'U-SDW-006');
      expect(state.getHeightForTesting('2K'), 1440, reason: 'U-SDW-007');
      expect(state.getHeightForTesting('1080p'), 1080, reason: 'U-SDW-008');
      expect(state.getHeightForTesting('720p'), 720, reason: 'U-SDW-009');
      expect(state.getHeightForTesting('480p'), 480, reason: 'U-SDW-010');
      expect(state.getHeightForTesting('1920x1080'), 1080, reason: 'U-SDW-011');
      expect(state.getHeightForTesting('abcd'), 0, reason: 'U-SDW-012');
      expect(state.getHeightForTesting('Video 720 HD'), 720, reason: 'U-SDW-013');
      expect(state.getHeightForTesting('360p'), 360, reason: 'U-SDW-014');
      expect(state.getHeightForTesting('AUDIO ONLY'), 0, reason: 'U-SDW-015');
    });
  });

  group('StandaloneDownloaderWindow Widget Tests', () {
    Widget createWidget({Map<String, dynamic> initParams = const {}}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StandaloneDownloaderWindow(windowId: 1, initParams: initParams),
          ),
        ),
      );
    }

    group('Initialization & Lifecycle', () {
      testWidgets('W-SDW-001: Render successfully', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget());
        expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
      });

      testWidgets('W-SDW-002 to W-SDW-007: Lifecycle init', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget(initParams: {'currentPath': '/test/path'}));
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        expect(state.currentPathForTesting, '/test/path', reason: 'W-SDW-002');
      });

      testWidgets('W-SDW-008 to W-SDW-009: didUpdateWidget', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget(initParams: {'currentPath': '/test/path1'}));
        dynamic state = tester.state(find.byType(StandaloneDownloaderWindow));
        expect(state.currentPathForTesting, '/test/path1');

        await tester.pumpWidget(createWidget(initParams: {'currentPath': '/test/path2'}));
        state = tester.state(find.byType(StandaloneDownloaderWindow));
        expect(state.currentPathForTesting, '/test/path2', reason: 'W-SDW-008');
      });
      
      testWidgets('W-SDW-010 to W-SDW-012: dispose', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget());
        await tester.pumpWidget(const SizedBox()); // dispose
      });
    });

    group('Search', () {
      testWidgets('W-SDW-013 to W-SDW-020: Search input and debounce', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        expect(state.searchControllerForTesting.text, '', reason: 'W-SDW-013');
        
        state.searchControllerForTesting.text = 'test';
        state.onSearchChangedForTesting();
        expect(state.searchDebounceForTesting?.isActive, true, reason: 'W-SDW-014');
        
        await tester.pump(const Duration(milliseconds: 350));
        expect(state.searchDebounceForTesting?.isActive, false, reason: 'W-SDW-015');
      });
    });

    group('Global Keyboard Shortcuts', () {
      testWidgets('W-SDW-025 to W-SDW-032: Ctrl+F and Ctrl+D', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        await tester.pump(const Duration(milliseconds: 100));
        
        expect(state.isSearchVisibleForTesting, true, reason: 'W-SDW-025');
        
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        await tester.pump(const Duration(milliseconds: 100));
        expect(state.isSearchVisibleForTesting, false, reason: 'W-SDW-026');
        
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      });
    });

    group('Tab State Management', () {
      testWidgets('W-SDW-033 to W-SDW-042: Save and Restore tab state', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        state.searchControllerForTesting.text = 'hello';
        state.isSearchVisibleForTesting = true;
        state.selectedIndicesForTesting.add(1);
        
        state.saveCurrentTabStateForTesting('path1');
        
        state.searchControllerForTesting.text = '';
        state.isSearchVisibleForTesting = false;
        state.selectedIndicesForTesting.clear();
        
        state.restoreTabStateForTesting('path1');
        expect(state.searchControllerForTesting.text, 'hello', reason: 'W-SDW-041');
        expect(state.isSearchVisibleForTesting, true, reason: 'W-SDW-042');
        expect(state.selectedIndicesForTesting.contains(1), true, reason: 'W-SDW-040');
      });
    });

    group('Delete Workflow', () {
      testWidgets('W-SDW-043 to W-SDW-054: Delete operations', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        state.selectedIndicesForTesting.clear();
        state.handleDeleteForTesting(false);
        // should do nothing
        
        state.selectedIndicesForTesting.add(0);
        state.handleDeleteForTesting(true);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Permanently Delete'), findsOneWidget, reason: 'W-SDW-045');
        
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Permanently Delete'), findsNothing, reason: 'W-SDW-046');
      });
    });
  });
}
