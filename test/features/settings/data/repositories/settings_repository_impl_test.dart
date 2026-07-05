import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/data/repositories/settings_repository_impl.dart';

// Minimal fake implementation of AppDatabase
class FakeAppDatabase implements AppDatabase {
  final Map<String, String> sorts = {};
  List<String> removedSorts = [];

  @override
  Future<void> setFolderSort(String path, String sortKey) async {
    sorts[path] = sortKey;
  }

  @override
  Future<void> removeFolderSorts(List<String> paths) async {
    removedSorts.addAll(paths);
  }
  
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
  });
}
