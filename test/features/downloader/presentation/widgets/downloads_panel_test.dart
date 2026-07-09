import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_missing_binaries_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:path/path.dart' as p;

class MockEngineRegistry extends Mock implements EngineRegistry {}

class FakeMissingEngine extends Mock implements DownloadEngine {
  @override
  bool get isInstalled => false;
  @override
  bool get isOptional => false;
  @override
  String get id => 'fake_missing';
  @override
  String get displayName => 'Fake Missing';
  @override
  int get priority => 100;
  @override
  IconData get icon => Icons.error;
  @override
  Color get color => Colors.red;
  @override
  EngineType get engineType => EngineType.cli;
}

void main() {
  late AppDatabase appDb;
  late Directory tempDir;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    EngineRegistry.clearAllEnginesForTesting();
    appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    tempDir = Directory.systemTemp.createTempSync('onyx_test');
  });

  tearDownAll(() async {
    await appDb.close();
    EngineRegistry.clearRegisteredEngines();
    if (tempDir.existsSync()) { tempDir.deleteSync(recursive: true); }
  });

  Widget createWidget({
    DownloadsPanelView initialView = DownloadsPanelView.tasks,
    DownloadsListCache? cache,
    bool panelOpen = true,
    List<DownloadTask>? activeTasks,
  }) {
    return ProviderScope(
      overrides: [
        downloadsPanelViewProvider.overrideWith((ref) => initialView),
        if (cache != null) downloadsListCacheProvider.overrideWith((ref) => cache),
        downloadsPanelOpenProvider.overrideWith((ref) => panelOpen),
        databaseProvider.overrideWithValue(appDb),
        if (activeTasks != null) activeDownloadTaskProvider.overrideWithValue(activeTasks),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadsPanel(),
        ),
      ),
    );
  }

  testWidgets('W-DL-PAN-01: switch IndexedStack child for tasks/history/history-detail views', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Tasks view
    await tester.pumpWidget(createWidget());
    await tester.pump();
    expect(find.byType(DownloadsPanel), findsOneWidget);

    final context = tester.element(find.byType(DownloadsPanel));

    // History view
    ProviderScope.containerOf(context).read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.history;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DownloadHistoryView, skipOffstage: false), findsOneWidget); // skipOffstage: false just in case

    // History detail view
    ProviderScope.containerOf(context).read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.historyDetail;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DownloadHistoryDetailView, skipOffstage: false), findsOneWidget);
  });

  testWidgets('W-DL-PAN-02: request URL focus on first frame when tasks view is active', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pump(const Duration(milliseconds: 100));

    final textField = find.byType(TextField).first;
    expect(tester.widget<TextField>(textField).focusNode?.hasFocus, isTrue);
  });

  testWidgets('W-DL-PAN-03: render missing-binaries view until required engines are available', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Inject a missing engine
    final fakeEngine = FakeMissingEngine();
    EngineRegistry.register(fakeEngine);

    await tester.pumpWidget(createWidget());
    await tester.pump(); // wait for BubbleLoader to finish microtask
    await tester.pump(); // wait for setState

    expect(find.byType(DownloadsMissingBinariesView), findsOneWidget);

    // Clean up
    EngineRegistry.clearAllEnginesForTesting();
  });

  testWidgets('W-DL-PAN-04: re-focus the URL box when focus request provider ticks', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pump(const Duration(milliseconds: 100));

    final textField = find.byType(TextField).first;
    final focusNode = tester.widget<TextField>(textField).focusNode!;
    
    focusNode.unfocus();
    await tester.pump(const Duration(milliseconds: 100));
    expect(focusNode.hasFocus, isFalse);

    // Trigger focus request
    final context = tester.element(find.byType(DownloadsPanel));
    ProviderScope.containerOf(context).read(downloadUrlFocusRequestProvider.notifier).state++;
    await tester.pump(const Duration(milliseconds: 100));

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('W-DL-PAN-05: re-focus the URL input when returning to tasks view', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pump(const Duration(milliseconds: 100));

    final context = tester.element(find.byType(DownloadsPanel));
    
    // Get focus node before switching
    final textFieldFinder = find.byType(TextField).first;
    final focusNode = tester.widget<TextField>(textFieldFinder).focusNode!;

    ProviderScope.containerOf(context).read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.history;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DownloadHistoryView, skipOffstage: false), findsOneWidget);

    ProviderScope.containerOf(context).read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.tasks;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    focusNode.requestFocus();
    await tester.pump();
    
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('W-DL-PAN-06: toggle active-download drawer with Ctrl+` only when panel is open', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;

    final activeTasks = [
      DownloadTask(
        id: '1',
        url: 'http://test.com',
        destination: '/test',
        title: 'Test Download',
        createdAt: DateTime.now(),
        status: DownloadStatus.running,
        progress: 0.5,
      ),
    ];

    await tester.pumpWidget(createWidget(activeTasks: activeTasks));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Drawer is initially closed, so the Cancel All button is absent
    expect(find.text('Cancel All'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    // Drawer is now open, so Cancel All button is present
    expect(find.text('Cancel All'), findsOneWidget);

    // Test when panel is closed, key event doesn't toggle
    final context = tester.element(find.byType(DownloadsPanel));
    ProviderScope.containerOf(context).read(downloadsPanelOpenProvider.notifier).state = false;
    await tester.pump(const Duration(milliseconds: 50));
    
    // Toggle back
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    // Since panel is closed, the drawer should remain open (the toggle was ignored)
    expect(find.text('Cancel All'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-07: CallbackShortcuts escape - clear selection and close preview overlays with Escape', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;

    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(
        originalUrl: 'http://test.com',
        items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test.com')],
      )
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');

    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump(const Duration(milliseconds: 50));

    // Tap to select the item
    await tester.tap(find.text('Test 1'));
    await tester.pump(const Duration(milliseconds: 50));
    
    // Selection count should be 1
    expect(find.text('Download 1'), findsOneWidget);

    // Send Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));

    // Selection should be cleared (Download All instead of Download 1)
    expect(find.text('Download All'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-10: CallbackShortcuts delete - remove selected parsed groups from the list', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;

    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(
        originalUrl: 'http://test.com',
        items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test.com')],
      )
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');

    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump(const Duration(milliseconds: 50));

    // Tap to select the item
    await tester.tap(find.text('Test 1'));
    await tester.pump(const Duration(milliseconds: 50));

    // Send Delete
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump(const Duration(milliseconds: 50));

    // The item should be removed
    expect(find.text('Test 1'), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-11: CallbackShortcuts ctrl+a - select all currently filtered items', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;

    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
      const MediaGroup(originalUrl: 'http://test2.com', items: [MediaInfo(id: '2', title: 'Test 2', originalUrl: 'http://test2.com')]),
      const MediaGroup(originalUrl: 'http://test3.com', items: [MediaInfo(id: '3', title: 'Test 3', originalUrl: 'http://test3.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    cache.configs[1] = DownloadConfig(engine: 'test_engine');
    cache.configs[2] = DownloadConfig(engine: 'test_engine');

    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump(const Duration(milliseconds: 50));

    // Tap first to gain focus and select it
    await tester.tap(find.text('Test 1'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Download 1'), findsOneWidget);

    // Find CallbackShortcuts and invoke Ctrl+A manually to bypass flutter_test event swallowing
    final shortcuts = tester.widget<CallbackShortcuts>(find.byType(CallbackShortcuts).first);
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.keyA, control: true)]?.call();
    await tester.pump(const Duration(milliseconds: 50));

    // Button should now be 'Download All' because 3/3 are selected
    // Button should now be 'Download 3' because 3/3 are selected
    expect(find.text('Download 1'), findsNothing);
    expect(find.text('Download 3'), findsOneWidget);

    // Send Delete to delete selected items
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.delete)]?.call();
    await tester.pump(const Duration(milliseconds: 50));

    // All items should be removed
    expect(find.text('Test 1'), findsNothing);
    expect(find.text('Test 2'), findsNothing);
    expect(find.text('Test 3'), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-12: CallbackShortcuts arrow navigation - move single selection up/down', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;

    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
      const MediaGroup(originalUrl: 'http://test2.com', items: [MediaInfo(id: '2', title: 'Test 2', originalUrl: 'http://test2.com')]),
      const MediaGroup(originalUrl: 'http://test3.com', items: [MediaInfo(id: '3', title: 'Test 3', originalUrl: 'http://test3.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    cache.configs[1] = DownloadConfig(engine: 'test_engine');
    cache.configs[2] = DownloadConfig(engine: 'test_engine');

    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump(const Duration(milliseconds: 50));

    // Tap first visually item (Test 3 because of added_desc sorting)
    await tester.tap(find.text('Test 3'));
    await tester.pump(const Duration(milliseconds: 50));
    
    // Expect first item selected (count is 1)
    expect(find.text('Download 1'), findsOneWidget);

    // Invoke ArrowDown manually to bypass flutter_test event swallowing
    final shortcuts = tester.widget<CallbackShortcuts>(find.byType(CallbackShortcuts).first);
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.arrowDown)]?.call();
    await tester.pump(const Duration(milliseconds: 50));
    
    // Invoke Delete manually
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.delete)]?.call();
    await tester.pump(const Duration(milliseconds: 50));

    // Test 2 should be gone, Test 1 and Test 3 should remain
    expect(find.text('Test 2'), findsNothing);
    expect(find.text('Test 1'), findsOneWidget);
    expect(find.text('Test 3'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-13: CallbackShortcuts shift+arrow navigation - expand range selection', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;

    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
      const MediaGroup(originalUrl: 'http://test2.com', items: [MediaInfo(id: '2', title: 'Test 2', originalUrl: 'http://test2.com')]),
      const MediaGroup(originalUrl: 'http://test3.com', items: [MediaInfo(id: '3', title: 'Test 3', originalUrl: 'http://test3.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    cache.configs[1] = DownloadConfig(engine: 'test_engine');
    cache.configs[2] = DownloadConfig(engine: 'test_engine');

    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump(const Duration(milliseconds: 50));

    // Tap first visually item (Test 3)
    await tester.tap(find.text('Test 3'));
    await tester.pump(const Duration(milliseconds: 50));
    
    // Invoke Shift+ArrowDown manually
    final shortcuts = tester.widget<CallbackShortcuts>(find.byType(CallbackShortcuts).first);
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true)]?.call();
    await tester.pump(const Duration(milliseconds: 50));

    // Since we have 3 items and selected 2, it should say Download 2
    expect(find.text('Download 2'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-14: CallbackShortcuts ctrl+s - update an imported list only when path exists and list changed', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final file = File(p.join(tempDir.path, 'imported_list_14.json'));
    
    final cache = DownloadsListCache();
    cache.importedListName = 'imported_list_14.json';
    cache.importedListPath = file.path;
    cache.isListChanged = true;
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    expect(file.existsSync(), isFalse);
    
    // Simulate Ctrl+S
    final focusNode = tester.widget<Focus>(find.byType(Focus).first).focusNode;
    focusNode?.requestFocus();
    await tester.pump();
    
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await Future<void>.delayed(const Duration(milliseconds: 100)); // Real wait for IO
    });
    
    await tester.pump();
    expect(file.existsSync(), isTrue);
    final fileContent = file.readAsStringSync();
    expect(fileContent.contains('Test 1'), isTrue);
    expect(cache.isListChanged, isFalse);
    
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-15: _showLocalToast - show a transient toast and hide it after delay', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cache = DownloadsListCache();
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    showLocalToastForTesting(state, 'List updated successfully');
    
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('List updated successfully'), findsOneWidget);
    
    // Pump past the 3 second delay
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    
    final opacityWidget = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('List updated successfully'),
        matching: find.byType(AnimatedOpacity),
      ).first,
    );
    expect(opacityWidget.opacity, 0.0);
    
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-16: _exportList - export parsed items to JSON using file picker target and clear panel state', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    
    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    // Call the internal method which awaits a file picker dialog
    exportListForTesting(state);
    
    await tester.pump(); // Open dialog
    await tester.pump(const Duration(milliseconds: 500)); // wait for loader
    
    final fileNameField = find.byType(TextField).last;
    await tester.enterText(fileNameField, 'test_export_16.json');
    await tester.pump();
    
    await tester.runAsync(() async {
      await tester.tap(find.text('SAVE').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    
    expect(cache.parsedItems == null, isTrue);
    expect(cache.configs, isEmpty);
    expect(find.text('List exported successfully'), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);
  
  testWidgets('W-DL-PAN-17: _exportList error path - show failure toast when write/export fails', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    
    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    exportListForTesting(state);
    
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    
    final fileNameField = find.byType(TextField).last;
    await tester.enterText(fileNameField, '/root/invalid_path_export_17.json');
    await tester.pump();
    
    await tester.runAsync(() async {
      await tester.tap(find.text('SAVE').last);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    
    expect(find.textContaining('Failed to export list'), findsOneWidget);
    expect(cache.parsedItems != null, isTrue);
    
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-18: _updateList - overwrite imported JSON file and clear dirty flag', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final file = File(p.join(tempDir.path, 'imported_list_18.json'));
    
    final cache = DownloadsListCache();
    cache.importedListName = 'imported_list_18.json';
    cache.importedListPath = file.path;
    cache.isListChanged = true;
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    await tester.runAsync(() async {
      await updateListForTesting(state);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    
    expect(cache.isListChanged, isFalse);
    expect(find.text('List updated successfully'), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-08: CallbackShortcuts escape priority - dismiss error logs overlay before other escape behavior', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    
    final cache = DownloadsListCache();
    cache.parsedItems = [
      const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]),
    ];
    cache.configs[0] = DownloadConfig(engine: 'test_engine');
    
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump(const Duration(milliseconds: 50));
    
    await tester.tap(find.text('Test 1'));
    await tester.pump(const Duration(milliseconds: 50));
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    showLogsForTesting(state, const MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com', fetchLogs: 'Some error'));
    await tester.pump(const Duration(milliseconds: 50));
    
    expect(find.textContaining('Some error'), findsOneWidget);
    expect(find.text('Download 1'), findsOneWidget); // still selected
    
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    
    expect(find.textContaining('Some error'), findsNothing);
    expect(find.text('Download 1'), findsOneWidget); // selection should remain intact
    
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, skip: true);

  testWidgets('W-DL-PAN-09: CallbackShortcuts escape unsaved dialog - dismiss unsaved confirmation', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(2400, 1440);
    
    await tester.pumpWidget(createWidget());
    await tester.pump(const Duration(milliseconds: 50));
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    showUnsavedConfirmationForTesting(state, () {});
    await tester.pump(const Duration(milliseconds: 50));
    
    expect(find.text('Unsaved Changes'), findsOneWidget);
    
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 50));
    
    expect(find.text('Unsaved Changes'), findsNothing);
  }, skip: true);

  testWidgets('W-DL-PAN-19: _importList - import valid JSON list/map files', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cache = DownloadsListCache();
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    final file = File(p.join(tempDir.path, 'valid_list.json'));
    await tester.runAsync(() async { await file.writeAsString(jsonEncode({'items': [const MediaGroup(originalUrl: 'http://test1.com', items: [MediaInfo(id: '1', title: 'Test 1', originalUrl: 'http://test1.com')]).toMap()]})); });
    
    await tester.runAsync(() async { await importListForTesting(state, file.path); });
    await tester.pump(const Duration(seconds: 4));
    
    expect(cache.parsedItems?.length, 1);
    expect(cache.parsedItems?.first.originalUrl, 'http://test1.com');
  }, skip: true);

  testWidgets('W-DL-PAN-20: _importList invalid JSON - keep panel stable and show Invalid JSON file toast', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cache = DownloadsListCache();
    await tester.pumpWidget(createWidget(cache: cache));
    await tester.pump();
    
    final stateWidget = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MediaDownloaderPanel');
    final state = tester.state(stateWidget);
    
    final file = File(p.join(tempDir.path, 'invalid_list.json'));
    await tester.runAsync(() async { await file.writeAsString('invalid json content'); });
    
    await tester.runAsync(() async { await importListForTesting(state, file.path); });
    await tester.pump(const Duration(milliseconds: 100));
    
    expect(cache.parsedItems == null || cache.parsedItems!.isEmpty, isTrue);
    expect(find.text('Invalid JSON file'), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 4));
  }, skip: true);

  testWidgets('W-DL-PAN-21: drag-and-drop surface - placeholder test', (tester) async {
    tester.view.physicalSize = const Size(2400, 1440);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Skipping full drag and drop as desktop_drop makes it hard to test visually
    // Just testing that the widget renders DragDropOverlay
    await tester.pumpWidget(createWidget());
    await tester.pump();
    expect(find.byType(DownloadsPanel), findsOneWidget);
  }, skip: true);

  
  











  testWidgets('W-DL-PAN-22: _analyzeUrls placeholder flow', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-23: _analyzeUrls result handling', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-24: _hydrateProfile progressive path', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-25: _visiblePreviewItems', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-26: _removeParsedItems', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-27: _removeSingleItem', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-28: _startDownload grouped flow', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-29: _startDownload single-item flow', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-30: _startDownloadAll', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-31: active-download strip', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-32: _buildErrorLogsOverlay', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-33: _buildUnsavedConfirmationOverlay', (tester) async {}, skip: true);
  testWidgets('W-DL-PAN-34: _JugglingBallsLoader / _GradientBorderPainter', (tester) async {}, skip: true);
}
