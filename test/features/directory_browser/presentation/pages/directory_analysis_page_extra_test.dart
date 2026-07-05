import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/pages/directory_analysis_page.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_analysis_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import 'mock_utils.dart';

class MockDirectoryRepository extends Mock implements DirectoryRepository {}
class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings();
}
class MockPinnedItemsNotifier extends PinnedItemsNotifier {
  @override
  Future<Map<String, int>> build() async => {};
}
class MockTabManager extends TabManager {
  @override
  TabManagerState build() {
    return TabManagerState(
      tabs: [TabState(id: 'mock-tab-id', currentPath: '/mock', history: ['/mock'])],
      activeTabIndex: 0,
    );
  }
}
class MockSelectionNotifier extends SelectionNotifier {
  @override
  SelectionState build() => SelectionState.empty;
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });
  group('Extra Analysis Page Tests', () {
    late MockDirectoryRepository mockRepo;
    late AppDatabase mockDb;
    late MockSettingsRepository mockSettingsRepo;
    
    setUp(() async {
      mockRepo = MockDirectoryRepository();
      mockDb = getMockDb();
      mockSettingsRepo = getMockSettingsRepo();
    });

    Future<void> pumpTestWidget(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: widget,
        ),
      );
    }

    Widget createTestableWidget({
      required DirectoryAnalysisResult initialData,
      List<dynamic>? extraOverrides,
    }) {
      return ProviderScope(
        overrides: [
          tabIdProvider.overrideWithValue('mock-tab-id'),
          directoryRepositoryProvider.overrideWithValue(mockRepo),
          databaseProvider.overrideWithValue(mockDb),
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
          tabManagerProvider.overrideWith(MockTabManager.new),
          directoryAnalysisProvider('/mock').overrideWith((ref) => Future.value(initialData)),
          if (extraOverrides != null) ...extraOverrides.cast(),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DirectoryAnalysisPage(path: '/mock'),
          ),
        ),
      );
    }
    
    final mockData = DirectoryAnalysisResult(
      path: '/mock',
      totalItems: 5,
      totalBytes: 1000,
      diskUsage: null,
      allFiles: [
        FileStatWithInfo(name: 'f1.txt', path: '/mock/f1.txt', stat: FileStatData(size: 100, modified: DateTime.now()), type: FileItemType.document),
        FileStatWithInfo(name: 'sub', path: '/mock/sub', stat: FileStatData(size: 0, modified: DateTime.now()), type: FileItemType.folder),
      ],
      categoryStats: {
        FileItemType.document: CategoryStats(count: 1, totalBytes: 100),
        FileItemType.folder: CategoryStats(count: 1),
        FileItemType.image: CategoryStats(),
        FileItemType.video: CategoryStats(),
        FileItemType.audio: CategoryStats(),
        FileItemType.archive: CategoryStats(),
        FileItemType.other: CategoryStats(),
      },
    );


    testWidgets('Renders DirectoryAnalysisPage with initial data', (tester) async {
      await pumpTestWidget(tester, createTestableWidget(initialData: mockData));
      await tester.pump();
      expect(find.byType(DirectoryAnalysisPage), findsOneWidget);
    });
  });
}
