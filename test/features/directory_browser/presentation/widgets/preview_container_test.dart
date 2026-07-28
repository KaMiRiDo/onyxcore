import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/preview_container.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings(openInStandaloneMode: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final methodChannelCalls = <MethodCall>[];

  setUp(() {
    db = AppDatabase.forTesting(drift.DatabaseConnection(NativeDatabase.memory()));
    methodChannelCalls.clear();

    // Set up mock channel handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        methodChannelCalls.add(methodCall);
        if (methodCall.method == 'create_window') {
          return 42; // mock viewId
        }
        return null;
      },
    );
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      null,
    );
  });

  Widget buildTestWidget({
    required FileItem item,
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: PreviewContainer(item: item),
        ),
      ),
    );
  }

  group('PreviewContainer Rendering', () {
    testWidgets('renders correctly for document (PDF)', (tester) async {
      final item = FileItem(
        path: '/home/user/document.pdf',
        name: 'document.pdf',
        type: FileItemType.document,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
        ],
      );

      await tester.pumpWidget(buildTestWidget(item: item, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(PreviewContainer), findsOneWidget);
      expect(find.text('PDF Preview not yet implemented'), findsOneWidget);
      expect(find.text('Double-tap to open in external viewer'), findsOneWidget);
    });

    testWidgets('renders unsupported message for unknown type', (tester) async {
      final item = FileItem(
        path: '/home/user/unknown.xyz',
        name: 'unknown.xyz',
        type: FileItemType.other,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
        ],
      );

      await tester.pumpWidget(buildTestWidget(item: item, container: container));
      await tester.pumpAndSettle();

      expect(find.byType(PreviewContainer), findsOneWidget);
      expect(find.text('Preview not supported for this file type'), findsOneWidget);
    });
  });

  group('Keyboard Shortcuts', () {
    testWidgets('Ctrl+W closes preview when marker editor is inactive', (tester) async {
      final item = FileItem(
        path: '/home/user/unknown.xyz',
        name: 'unknown.xyz',
        type: FileItemType.other, // Use other to avoid initializing media widgets
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          previewFileProvider.overrideWith((ref) => item),
          previewHudVisibleProvider.overrideWith((ref) => false),
          isMarkerEditorActiveProvider.overrideWith((ref) => false),
        ],
      );

      await tester.pumpWidget(buildTestWidget(item: item, container: container));
      await tester.pumpAndSettle();

      // Trigger Ctrl+W
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // previewFileProvider state should be null, and HUD should be visible
      expect(container.read(previewFileProvider), isNull);
      expect(container.read(previewHudVisibleProvider), isTrue);
    });

    testWidgets('Ctrl+W does NOT close preview when marker editor is active', (tester) async {
      final item = FileItem(
        path: '/home/user/unknown.xyz',
        name: 'unknown.xyz',
        type: FileItemType.other,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          previewFileProvider.overrideWith((ref) => item),
          previewHudVisibleProvider.overrideWith((ref) => false),
          isMarkerEditorActiveProvider.overrideWith((ref) => true),
        ],
      );

      await tester.pumpWidget(buildTestWidget(item: item, container: container));
      await tester.pumpAndSettle();

      // Trigger Ctrl+W
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      // Should not close
      expect(container.read(previewFileProvider), equals(item));
    });

    testWidgets('Key F toggles HUD visibility', (tester) async {
      await tester.runAsync(() async {
        final item = FileItem(
          path: '/home/user/unknown.xyz',
          name: 'unknown.xyz',
          type: FileItemType.other,
          sizeBytes: 1024,
          modified: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsProvider.overrideWith(FakeSettingsNotifier.new),
            previewFileProvider.overrideWith((ref) => item),
            previewHudVisibleProvider.overrideWith((ref) => true),
            isMarkerEditorActiveProvider.overrideWith((ref) => false),
          ],
        );

        await tester.pumpWidget(buildTestWidget(item: item, container: container));
        await tester.pump();

        // Wait 310ms to bypass throttle threshold
        await Future<void>.delayed(const Duration(milliseconds: 310));

        // Press F key
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.pump();

        // HUD should toggle to false
        expect(container.read(previewHudVisibleProvider), isFalse);

        // Pressing again quickly (within 300ms) should be throttled and NOT toggle back
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.pump();
        expect(container.read(previewHudVisibleProvider), isFalse);

        // Wait 310ms and press F again
        await Future<void>.delayed(const Duration(milliseconds: 310));
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.pump();
        expect(container.read(previewHudVisibleProvider), isTrue);
      });
    });
  });

  group('Double-Tap Interactions', () {
    testWidgets('Double-tap triggers PersistentViewerManager and closes preview', (tester) async {
      final item = FileItem(
        path: '/home/user/unknown.xyz',
        name: 'unknown.xyz',
        type: FileItemType.other, // onDoubleTap is enabled for other type
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          previewFileProvider.overrideWith((ref) => item),
          sortedDirectoryItemsProvider.overrideWithValue(AsyncValue.data([item])),
        ],
      );

      PersistentViewerManager.reset();

      await tester.pumpWidget(buildTestWidget(item: item, container: container));
      await tester.pumpAndSettle();

      // Perform double tap gesture on the preview container
      await tester.tap(find.byType(PreviewContainer));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PreviewContainer));
      await tester.pumpAndSettle();

      // Method channel should be invoked to create a window
      final createWindowCall = methodChannelCalls.firstWhere((c) => c.method == 'create_window');
      expect(createWindowCall, isNotNull);

      // The preview should close internally
      expect(container.read(previewFileProvider), isNull);
    });

    testWidgets('Double-tap does not trigger for document', (tester) async {
      final item = FileItem(
        path: '/home/user/document.pdf',
        name: 'document.pdf',
        type: FileItemType.document,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          settingsProvider.overrideWith(FakeSettingsNotifier.new),
          previewFileProvider.overrideWith((ref) => item),
        ],
      );

      await tester.pumpWidget(buildTestWidget(item: item, container: container));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PreviewContainer));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PreviewContainer));
      await tester.pumpAndSettle();

      // No method channel call
      expect(methodChannelCalls.where((c) => c.method == 'create_window'), isEmpty);
    });
  });
}
