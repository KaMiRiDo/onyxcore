import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/hero_audio_player.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/playlist_sidebar.dart';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:google_fonts/google_fonts.dart';

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings();
  }
  @override
  Future<void> saveSettings(AppSettings newSettings) async {
    state = AsyncData(newSettings);
  }
}

void main() {
  late AppDatabase db;
  late FileItem dummyFile;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '.';
        }
        return null;
      },
    );

    HttpOverrides.global = null;

    MediaKit.ensureInitialized();
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    dummyFile = FileItem(
      path: '/test.mp3',
      name: 'test.mp3',
      type: FileItemType.audio,
      modified: DateTime.now(),
      sizeBytes: 100,
    );
  });

  tearDownAll(() async {
    await db.close();
  });

  group('AudioPlayerView', () {
    testWidgets('Initializes player, triggers streams, and handles keyboard shortcuts', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              currentTrackProvider.overrideWith((ref) => dummyFile),
              audioQueueProvider.overrideWith((ref) => [dummyFile]),
              audioPlayingProvider.overrideWith((ref) => Stream.value(false)),
              audioRootPathProvider.overrideWith((ref) => '/'),
              audioCurrentPathProvider.overrideWith((ref) => '/'),
              audioPlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              settingsProvider.overrideWith(() => MockSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AudioPlayerView(item: dummyFile, isStandalone: true, windowId: '100'),
              ),
            ),
          ),
        );
        
        // Wait for real isolates and media_kit
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));

        // Trigger focus manually
        PersistentViewerManager.getFocusTrigger(100).value++;
        await tester.pump();

        // Check if HeroAudioPlayer is rendered
        expect(find.byType(HeroAudioPlayer), findsOneWidget);

        // Test spacebar (play/pause)
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump(const Duration(milliseconds: 100));

        // Test arrow left/right (seek)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        
        // Test volume up/down
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

        // Simulate Ctrl+Shift+P
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump(const Duration(milliseconds: 100));

        // Ctrl+R (reload)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        // Ctrl+A (select all)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump(const Duration(milliseconds: 100));

        // Test normal delete
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pump(const Duration(milliseconds: 100));
        // Dismiss dialog
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 100));

        // Test Shift+Delete
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump(const Duration(milliseconds: 100));
        // Dismiss dialog
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 100));

        // Test list toggle (L)
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pump(const Duration(milliseconds: 100));

        // Test mute (M)
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.pump(const Duration(milliseconds: 100));

        // Test properties (Ctrl+I)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        await tester.pump(const Duration(milliseconds: 100));
        // Dismiss dialog
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 100));

        // Let more events fire
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      });

      // Clean up the widget tree to kill timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('AudioPlayerView hides favorite and playlist buttons when is_audio_play_only is true', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              currentTrackProvider.overrideWith((ref) => dummyFile),
              audioQueueProvider.overrideWith((ref) => [dummyFile]),
              audioPlayingProvider.overrideWith((ref) => Stream.value(false)),
              audioRootPathProvider.overrideWith((ref) => '/'),
              audioCurrentPathProvider.overrideWith((ref) => '/'),
              audioPlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              settingsProvider.overrideWith(() => MockSettingsNotifier()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AudioPlayerView(
                  item: dummyFile, 
                  isStandalone: true, 
                  windowId: '101',
                  initParams: const {'is_audio_play_only': true},
                ),
              ),
            ),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 500));

        // Wait for render
        expect(find.byType(HeroAudioPlayer), findsOneWidget);

        // Verify Favorite icon is missing
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.favorite), findsNothing);

        // Verify Playlist toggle icon is missing
        expect(find.byIcon(Icons.playlist_play), findsNothing);
      });

      // Clean up the widget tree to kill timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1000));
    });
  });
}
