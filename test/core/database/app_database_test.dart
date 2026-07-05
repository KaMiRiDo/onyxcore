import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('AppDatabase FolderSortPreferences', () {
    test('setFolderSort inserts or updates sort order', () async {
      await database.setFolderSort('/test/path', 'lastModified');
      final sorts = await database.getAllFolderSorts();
      expect(sorts['/test/path'], 'lastModified');

      // Update
      await database.setFolderSort('/test/path', 'sizeLargeToSmall');
      final updatedSorts = await database.getAllFolderSorts();
      expect(updatedSorts['/test/path'], 'sizeLargeToSmall');
    });

    test('removeFolderSorts removes matching paths and subdirectories', () async {
      await database.setFolderSort('/test/path', 'lastModified');
      await database.setFolderSort('/test/path/child', 'aToZ');
      await database.setFolderSort('/other/path', 'zToA');

      await database.removeFolderSorts(['/test/path']);

      final sorts = await database.getAllFolderSorts();
      expect(sorts.containsKey('/test/path'), isFalse);
      expect(sorts.containsKey('/test/path/child'), isFalse);
      expect(sorts.containsKey('/other/path'), isTrue);
      expect(sorts['/other/path'], 'zToA');
    });
  });
}
