import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/download_history_database.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late DownloadHistoryDatabase db;
  late String dbPath;
  late String legacyJsonPath;

  setUpAll(() {
    dbPath = p.join(Directory.systemTemp.path, 'onyxcore_test', 'download_history.sqlite');
    legacyJsonPath = p.join(Directory.systemTemp.path, 'onyxcore_test', 'download_history.json');
  });

  setUp(() {
    // Clean up test environment before each test
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) dbFile.deleteSync();
    
    final legacyFile = File(legacyJsonPath);
    if (legacyFile.existsSync()) legacyFile.deleteSync();
    
    final migratedFile = File('$legacyJsonPath.migrated');
    if (migratedFile.existsSync()) migratedFile.deleteSync();

    db = DownloadHistoryDatabase();
  });

  tearDown(() {
    try {
      db.dispose();
    } catch (_) {}
    
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) dbFile.deleteSync();
  });

  DownloadHistoryEntry _createDummyEntry(String id, {String statusName = 'pending', DateTime? createdAt}) {
    return DownloadHistoryEntry(
      id: id,
      title: 'Test Video $id',
      statusName: statusName,
      downloadType: 'video',
      url: 'http://test.com/$id',
      destination: '/tmp/dest_$id.mp4',
      logs: ['Log 1', 'Log 2'],
      createdAt: createdAt ?? DateTime(2023, 1, 1),
    );
  }

  group('DownloadHistoryDatabase Unit Tests', () {
    group('1. Initialization & Schema', () {
      test('U-DL-HDB-01: Create SQLite database file and parent dirs if missing', () {
        expect(File(dbPath).existsSync(), isFalse);
        db.init();
        expect(File(dbPath).existsSync(), isTrue);
      });

      test('U-DL-HDB-02: Open existing database without recreating', () {
        db.init();
        db.insertEntry(_createDummyEntry('1'));
        db.dispose();

        // Re-open
        final db2 = DownloadHistoryDatabase();
        db2.init();
        expect(db2.getTotalCount(), 1);
        db2.dispose();
      });
    });

    group('2. Legacy JSON Migration', () {
      test('U-DL-HDB-03: Migrate data from JSON file if exists', () {
        final legacyFile = File(legacyJsonPath);
        legacyFile.parent.createSync(recursive: true);
        
        final dummy1 = _createDummyEntry('1');
        final dummy2 = _createDummyEntry('2');
        
        legacyFile.writeAsStringSync(jsonEncode([
          dummy1.toJson(),
          dummy2.toJson(),
        ]));

        db.init();
        expect(db.getTotalCount(), 2);
        expect(File('$legacyJsonPath.migrated').existsSync(), isTrue);
        expect(legacyFile.existsSync(), isFalse);
      });

      test('U-DL-HDB-04: Gracefully handle corrupt JSON file', () {
        final legacyFile = File(legacyJsonPath);
        legacyFile.parent.createSync(recursive: true);
        legacyFile.writeAsStringSync('corrupt json {');

        // Should not crash
        db.init();
        expect(db.getTotalCount(), 0);
      });

      test('U-DL-HDB-05: No-op when legacy file does not exist', () {
        expect(File(legacyJsonPath).existsSync(), isFalse);
        db.init();
        expect(db.getTotalCount(), 0);
      });

      test('U-DL-HDB-06: Use INSERT OR IGNORE to skip duplicates', () {
        // Init DB and insert entry '1'
        db.init();
        db.insertEntry(_createDummyEntry('1', statusName: 'completed'));
        
        // Now mock legacy file with entry '1' (different status) and entry '2'
        final legacyFile = File(legacyJsonPath);
        final dummy1Legacy = _createDummyEntry('1', statusName: 'pending');
        final dummy2 = _createDummyEntry('2');
        legacyFile.writeAsStringSync(jsonEncode([
          dummy1Legacy.toJson(),
          dummy2.toJson(),
        ]));

        // Force migration manually since init() already opened db, or we can re-init
        db.dispose();
        
        final db2 = DownloadHistoryDatabase();
        db2.init(); // Triggers migration
        
        expect(db2.getTotalCount(), 2);
        // Existing entry '1' should remain 'completed'
        expect(db2.getEntry('1')?.statusName, 'completed');
        db2.dispose();
      });
    });

    group('3. Insert & Upsert', () {
      test('U-DL-HDB-07: Insert new entry successfully', () {
        db.init();
        db.insertEntry(_createDummyEntry('abc'));
        final entry = db.getEntry('abc');
        expect(entry, isNotNull);
        expect(entry?.id, 'abc');
      });

      test('U-DL-HDB-08: Update existing entry via UPSERT', () {
        db.init();
        db.insertEntry(_createDummyEntry('1', statusName: 'pending'));
        db.insertEntry(_createDummyEntry('1', statusName: 'completed'));
        
        final entry = db.getEntry('1');
        expect(entry?.statusName, 'completed');
        expect(db.getTotalCount(), 1);
      });

      test('U-DL-HDB-09: Serialize logs list as JSON', () {
        db.init();
        db.insertEntry(_createDummyEntry('1'));
        final entry = db.getEntry('1');
        expect(entry?.logs, ['Log 1', 'Log 2']);
      });

      test('U-DL-HDB-10: Handle null completedAt', () {
        db.init();
        db.insertEntry(_createDummyEntry('1'));
        final entry = db.getEntry('1');
        expect(entry?.completedAt, isNull);
      });
    });

    group('4. Read Operations', () {
      test('U-DL-HDB-11: Return entries ordered by createdAt DESC', () {
        db.init();
        final e1 = _createDummyEntry('1', createdAt: DateTime(2023, 1, 1));
        final e2 = _createDummyEntry('2', createdAt: DateTime(2023, 1, 3));
        final e3 = _createDummyEntry('3', createdAt: DateTime(2023, 1, 2));
        
        db.insertEntry(e1);
        db.insertEntry(e2);
        db.insertEntry(e3);

        final entries = db.getEntries();
        expect(entries[0].id, '2'); // latest
        expect(entries[1].id, '3');
        expect(entries[2].id, '1'); // oldest
      });

      test('U-DL-HDB-12: Respect pagination limits and offsets', () {
        db.init();
        for (int i = 0; i < 10; i++) {
          db.insertEntry(_createDummyEntry('$i', createdAt: DateTime(2023, 1, i + 1)));
        }
        
        final entries = db.getEntries(limit: 5, offset: 2);
        expect(entries.length, 5);
        // IDs inserted in order of createdAt: 0..9
        // ordered DESC: 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
        // offset 2 means we skip 9 and 8. First is 7.
        expect(entries.first.id, '7');
        expect(entries.last.id, '3');
      });

      test('U-DL-HDB-13: Return empty list for empty DB', () {
        db.init();
        expect(db.getEntries(), isEmpty);
      });

      test('U-DL-HDB-14: Accurately count rows', () {
        db.init();
        for (int i = 0; i < 4; i++) {
          db.insertEntry(_createDummyEntry('$i'));
        }
        expect(db.getTotalCount(), 4);
      });

      test('U-DL-HDB-15: Return 0 for empty DB', () {
        db.init();
        expect(db.getTotalCount(), 0);
      });

      test('U-DL-HDB-16: Return entry by ID', () {
        db.init();
        db.insertEntry(_createDummyEntry('abc'));
        expect(db.getEntry('abc'), isNotNull);
      });

      test('U-DL-HDB-17: Return null for non-existent ID', () {
        db.init();
        expect(db.getEntry('xyz'), isNull);
      });
    });

    group('5. Delete Operations', () {
      test('U-DL-HDB-18: Delete specific rows by IDs', () {
        db.init();
        db.insertEntry(_createDummyEntry('A'));
        db.insertEntry(_createDummyEntry('B'));
        db.insertEntry(_createDummyEntry('C'));
        
        db.deleteEntries({'A', 'C'});
        expect(db.getTotalCount(), 1);
        expect(db.getEntry('B'), isNotNull);
        expect(db.getEntry('A'), isNull);
      });

      test('U-DL-HDB-19: No-op for empty set', () {
        db.init();
        db.insertEntry(_createDummyEntry('A'));
        db.deleteEntries({});
        expect(db.getTotalCount(), 1);
      });

      test('U-DL-HDB-20: Truncate and vacuum database', () {
        db.init();
        db.insertEntry(_createDummyEntry('A'));
        db.clearAll();
        expect(db.getTotalCount(), 0);
      });
    });

    group('6. File Size & Disposal', () {
      test('U-DL-HDB-21: Return DB file size in bytes', () {
        db.init();
        db.insertEntry(_createDummyEntry('A'));
        expect(db.fileSize, greaterThan(0));
      });

      test('U-DL-HDB-22: Return 0 when DB file doesn\'t exist', () {
        // Ensure not initialized
        expect(db.fileSize, 0);
      });

      test('U-DL-HDB-23: Close database without crash', () {
        db.init();
        db.dispose();
        // calling dispose again throws in sqlite3, but our test just verifies the first dispose doesn't crash
        expect(true, isTrue);
      });
    });

    group('7. Internal Row Parsing', () {
      test('U-DL-HDB-24: Correctly deserialize all fields from DB row', () {
        db.init();
        final original = DownloadHistoryEntry(
          id: '1',
          title: 'Title',
          statusName: 'error',
          downloadType: 'audio',
          errorMessage: 'some error',
          url: 'http://u',
          destination: '/d',
          logs: ['a', 'b'],
          createdAt: DateTime(2023, 1, 1).toUtc(),
          completedAt: DateTime(2023, 1, 2).toUtc(),
        );
        db.insertEntry(original);
        final retrieved = db.getEntry('1')!;
        
        expect(retrieved.id, original.id);
        expect(retrieved.title, original.title);
        expect(retrieved.statusName, original.statusName);
        expect(retrieved.downloadType, original.downloadType);
        expect(retrieved.errorMessage, original.errorMessage);
        expect(retrieved.url, original.url);
        expect(retrieved.destination, original.destination);
        expect(retrieved.logs, original.logs);
        expect(retrieved.createdAt, original.createdAt);
        expect(retrieved.completedAt, original.completedAt);
      });

      test('U-DL-HDB-25: Handle null completedAt column', () {
        db.init();
        db.insertEntry(_createDummyEntry('1'));
        final retrieved = db.getEntry('1')!;
        expect(retrieved.completedAt, isNull);
      });

      test('U-DL-HDB-26: Handle null errorMessage column', () {
        db.init();
        db.insertEntry(_createDummyEntry('1'));
        final retrieved = db.getEntry('1')!;
        expect(retrieved.errorMessage, isNull);
      });
    });
  });
}
