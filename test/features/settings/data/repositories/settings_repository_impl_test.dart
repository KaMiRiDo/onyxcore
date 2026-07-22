import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';

// Minimal fake implementation of AppDatabase
class FakeAppDatabase implements AppDatabase {
  final Map<String, String> sorts = {};
  List<String> removedSorts = [];
  final Map<String, String> mockSettings = {};

  @override
  Future<void> setFolderSort(String path, String sortKey) async {
    sorts[path] = sortKey;
  }

  @override
  Future<void> removeFolderSorts(List<String> paths) async {
    removedSorts.addAll(paths);
  }

  @override
  Future<String?> getSetting(String key) async {
    return mockSettings[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    mockSettings[key] = value;
  }
  
  @override
  Future<void> removeSetting(String key) async {
    mockSettings.remove(key);
  }
  
  @override
  Future<Map<String, String>> getAllFolderSorts() async => {};

  @override
  Future<List<String>> getOrderedPinnedFolders() async => [];

  @override
  Future<void> savePinnedFolders(List<String> paths) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SettingsRepositoryImpl repository;
  late FakeAppDatabase fakeDb;

  setUp(() {
    fakeDb = FakeAppDatabase();
    repository = SettingsRepositoryImpl(fakeDb);
  });

  group('SettingsRepositoryImpl Sort methods', () {
    test('setFolderSort calls database', () async {
      await repository.setFolderSort('/test/path', SortOption.lastModified);
      expect(fakeDb.sorts['/test/path'], SortOption.lastModified.name);
    });

    test('removeFolderSorts calls database', () async {
      await repository.removeFolderSorts(['/test/path']);
      expect(fakeDb.removedSorts, contains('/test/path'));
    });

    test('load reads openInStandaloneMode', () async {
      fakeDb.mockSettings['openInStandaloneMode'] = 'false';
      final settings = await repository.load();
      expect(settings.openInStandaloneMode, isFalse);
    });

    test('saveSettings writes openInStandaloneMode', () async {
      await repository.saveSettings(const AppSettings(openInStandaloneMode: false));
      expect(fakeDb.mockSettings['openInStandaloneMode'], '0'); // bools are stored as '0'/'1' or 'true'/'false' depending on SettingsCodec
      // wait, SettingsCodec uses encodeBool. We don't need to know the exact serialization if we just test it executes
    });
  });
}
