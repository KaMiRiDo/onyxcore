import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class FakeAppDatabaseForNotifier implements AppDatabase {
  @override
  Stream<List<Setting>> watchAllSettings() => Stream.empty();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsRepository implements SettingsRepository {
  AppSettings currentSettings = const AppSettings(
    
  );

  @override
  Future<AppSettings> load() async {
    return currentSettings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    currentSettings = settings;
  }

  @override
  Future<void> setFolderSort(String path, SortOption option) async {}

  @override
  Future<void> removeFolderSorts(List<String> paths) async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late FakeSettingsRepository fakeRepo;
  late FakeAppDatabaseForNotifier fakeAppDb;

  setUp(() {
    fakeRepo = FakeSettingsRepository();
    fakeAppDb = FakeAppDatabaseForNotifier();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(fakeRepo),
        databaseProvider.overrideWithValue(fakeAppDb),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('setFolderSort updates local state', () async {
    final notifier = container.read(settingsProvider.notifier);
    
    // Await initialization
    await container.read(settingsProvider.future);

    await notifier.setFolderSort('/some/path', SortOption.lastModified);
    
    final state = container.read(settingsProvider).value;
    expect(state?.gallerySortSettings['/some/path'], SortOption.lastModified.name);
  });

  test('cleanupFolderSorts removes exact paths and child paths from local state', () async {
    // Inject pre-existing sorts
    fakeRepo.currentSettings = const AppSettings(
      gallerySortSettings: {
        '/test/dir': 'lastModified',
        '/test/dir/child': 'aToZ',
        '/other/dir': 'zToA',
      }
    );
    
    final notifier = container.read(settingsProvider.notifier);
    // Await initialization
    await container.read(settingsProvider.future);

    await notifier.cleanupFolderSorts(['/test/dir']);

    final state = container.read(settingsProvider).value;
    expect(state?.gallerySortSettings.containsKey('/test/dir'), isFalse);
    expect(state?.gallerySortSettings.containsKey('/test/dir/child'), isFalse);
    expect(state?.gallerySortSettings.containsKey('/other/dir'), isTrue);
  });
}
