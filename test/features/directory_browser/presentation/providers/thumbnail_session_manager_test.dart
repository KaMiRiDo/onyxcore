import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session_manager.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import '../pages/mock_utils.dart';

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings();
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });

  group('ThumbnailSessionManager', () {
    late ProviderContainer container;

    setUp(() {
      final mockDb = getMockDb();
      final mockSettingsRepo = getMockSettingsRepo();

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('creates active session for the initial folder in active tab', () {
      final session = container.read(activeThumbnailSessionProvider);
      expect(session, isNotNull);
      expect(session!.folderPath, Platform.environment['HOME'] ?? '/');
      expect(session.isCancelled, isFalse);
      expect(session.isDisposed, isFalse);
    });

    test('cancels old session and creates a new session when folder path changes', () {
      final initialSession = container.read(activeThumbnailSessionProvider);
      expect(initialSession, isNotNull);
      expect(initialSession!.folderPath, Platform.environment['HOME'] ?? '/');

      // Navigate to a new directory
      container.read(currentPathProvider.notifier).state = '/test/folder2';

      final newSession = container.read(activeThumbnailSessionProvider);
      expect(newSession, isNotNull);
      expect(newSession!.folderPath, '/test/folder2');

      // Old session must have been cancelled
      expect(initialSession.isCancelled, isTrue);
      expect(newSession.isCancelled, isFalse);
      expect(identical(initialSession, newSession), isFalse);
    });

    test('cancels old tab session and switches active session when active tab changes', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      final initialTabState = container.read(tabManagerProvider);
      final initialTabId = initialTabState.activeTab.id;
      final session1 = container.read(activeThumbnailSessionProvider);

      expect(session1, isNotNull);
      expect(session1!.tabId, initialTabId);

      // Add and switch to a second tab
      tabManager.addTab(path: '/test/tab2_folder');

      final newTabState = container.read(tabManagerProvider);
      expect(newTabState.activeTabIndex, 1);
      final tab2Id = newTabState.activeTab.id;

      final session2 = container.read(activeThumbnailSessionProvider);
      expect(session2, isNotNull);
      expect(session2!.tabId, tab2Id);
      expect(session2.folderPath, '/test/tab2_folder');

      // First session should be cancelled
      expect(session1.isCancelled, isTrue);
      expect(session2.isCancelled, isFalse);
    });

    test('returns null session when browsing the thumbnail cache directory to prevent recursive generation', () {
      final home = Platform.environment['HOME'] ?? '/tmp';
      final cachePath = '$home/.cache/onyxcore/thumbnails';

      container.read(currentPathProvider.notifier).state = cachePath;

      final session = container.read(activeThumbnailSessionProvider);
      expect(session, isNull);

      // Subdirectory in cache
      container.read(currentPathProvider.notifier).state = '$cachePath/normal';
      final subSession = container.read(activeThumbnailSessionProvider);
      expect(subSession, isNull);
    });

    test('disposes active session on container disposal', () {
      final session = container.read(activeThumbnailSessionProvider);
      expect(session, isNotNull);
      expect(session!.isDisposed, isFalse);

      container.dispose();
      expect(session.isDisposed, isTrue);
    });
  });
}
