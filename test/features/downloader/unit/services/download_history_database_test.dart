import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart' hide DownloadHistoryEntry;
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/services/download_history_database.dart';

void main() {
  late AppDatabase appDb;
  late DownloadHistoryDatabase db;

  setUp(() {
    appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    db = DownloadHistoryDatabase(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  DownloadHistoryEntry createDummyEntry(String id, {String statusName = 'pending', DateTime? createdAt}) {
    return DownloadHistoryEntry(
      id: id,
      title: 'Test Video $id',
      statusName: statusName,
      downloadType: 'video',
      url: 'http://test.com/$id',
      destination: '/tmp/dest_$id.mp4',
      logs: ['Log 1', 'Log 2'],
      createdAt: createdAt ?? DateTime(2023),
    );
  }

  group('DownloadHistoryDatabase Unit Tests', () {
    group('1. Initialization & Schema', () {
      test('U-DL-HDB-01: Init is a no-op', () {
        db.init(); // Should not crash
        expect(true, isTrue);
      });
    });

    group('3. Insert & Upsert', () {
      test('U-DL-HDB-07: Insert new entry successfully', () async {
        await db.insertEntry(createDummyEntry('abc'));
        final entry = await db.getEntry('abc');
        expect(entry, isNotNull);
        expect(entry?.id, 'abc');
      });

      test('U-DL-HDB-08: Update existing entry via UPSERT', () async {
        await db.insertEntry(createDummyEntry('1'));
        await db.insertEntry(createDummyEntry('1', statusName: 'completed'));
        
        final entry = await db.getEntry('1');
        expect(entry?.statusName, 'completed');
        expect(await db.getTotalCount(), 1);
      });

      test('U-DL-HDB-09: Serialize logs list as JSON', () async {
        await db.insertEntry(createDummyEntry('1'));
        final entry = await db.getEntry('1');
        expect(entry?.logs, ['Log 1', 'Log 2']);
      });

      test('U-DL-HDB-10: Handle null completedAt', () async {
        await db.insertEntry(createDummyEntry('1'));
        final entry = await db.getEntry('1');
        expect(entry?.completedAt, isNull);
      });
    });

    group('4. Read Operations', () {
      test('U-DL-HDB-11: Return entries ordered by createdAt DESC', () async {
        final e1 = createDummyEntry('1', createdAt: DateTime(2023));
        final e2 = createDummyEntry('2', createdAt: DateTime(2023, 1, 3));
        final e3 = createDummyEntry('3', createdAt: DateTime(2023, 1, 2));
        
        await db.insertEntry(e1);
        await db.insertEntry(e2);
        await db.insertEntry(e3);

        final entries = await db.getEntries();
        expect(entries[0].id, '2'); // latest
        expect(entries[1].id, '3');
        expect(entries[2].id, '1'); // oldest
      });

      test('U-DL-HDB-12: Respect pagination limits and offsets', () async {
        for (var i = 0; i < 10; i++) {
          await db.insertEntry(createDummyEntry('$i', createdAt: DateTime(2023, 1, i + 1)));
        }
        
        final entries = await db.getEntries(limit: 5, offset: 2);
        expect(entries.length, 5);
        // IDs inserted in order of createdAt: 0..9
        // ordered DESC: 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
        // offset 2 means we skip 9 and 8. First is 7.
        expect(entries.first.id, '7');
        expect(entries.last.id, '3');
      });

      test('U-DL-HDB-13: Return empty list for empty DB', () async {
        expect(await db.getEntries(), isEmpty);
      });

      test('U-DL-HDB-14: Accurately count rows', () async {
        for (var i = 0; i < 4; i++) {
          await db.insertEntry(createDummyEntry('$i'));
        }
        expect(await db.getTotalCount(), 4);
      });

      test('U-DL-HDB-15: Return 0 for empty DB', () async {
        expect(await db.getTotalCount(), 0);
      });

      test('U-DL-HDB-16: Return entry by ID', () async {
        await db.insertEntry(createDummyEntry('abc'));
        expect(await db.getEntry('abc'), isNotNull);
      });

      test('U-DL-HDB-17: Return null for non-existent ID', () async {
        expect(await db.getEntry('xyz'), isNull);
      });
    });

    group('5. Delete Operations', () {
      test('U-DL-HDB-18: Delete specific rows by IDs', () async {
        await db.insertEntry(createDummyEntry('A'));
        await db.insertEntry(createDummyEntry('B'));
        await db.insertEntry(createDummyEntry('C'));
        
        await db.deleteEntries({'A', 'C'});
        expect(await db.getTotalCount(), 1);
        expect(await db.getEntry('B'), isNotNull);
        expect(await db.getEntry('A'), isNull);
      });

      test('U-DL-HDB-19: No-op for empty set', () async {
        await db.insertEntry(createDummyEntry('A'));
        await db.deleteEntries({});
        expect(await db.getTotalCount(), 1);
      });

      test('U-DL-HDB-20: Truncate and vacuum database', () async {
        await db.insertEntry(createDummyEntry('A'));
        await db.clearAll();
        expect(await db.getTotalCount(), 0);
      });
    });

    group('6. File Size & Disposal', () {
      test('U-DL-HDB-21: Return DB file size as 0 (not tracked via single file)', () {
        expect(db.fileSize, 0);
      });

      test('U-DL-HDB-23: Close database without crash', () {
        db.dispose();
        expect(true, isTrue);
      });
    });

    group('7. Internal Row Parsing', () {
      test('U-DL-HDB-24: Correctly deserialize all fields from DB row', () async {
        final original = DownloadHistoryEntry(
          id: '1',
          title: 'Title',
          statusName: 'error',
          downloadType: 'audio',
          errorMessage: 'some error',
          url: 'http://u',
          destination: '/d',
          logs: ['a', 'b'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(1672531200000), // DateTime(2023, 1, 1).toUtc()
          completedAt: DateTime.fromMillisecondsSinceEpoch(1672617600000), // DateTime(2023, 1, 2).toUtc()
        );
        await db.insertEntry(original);
        final retrieved = (await db.getEntry('1'))!;
        
        expect(retrieved.id, original.id);
        expect(retrieved.title, original.title);
        expect(retrieved.statusName, original.statusName);
        expect(retrieved.downloadType, original.downloadType);
        expect(retrieved.errorMessage, original.errorMessage);
        expect(retrieved.url, original.url);
        expect(retrieved.destination, original.destination);
        expect(retrieved.logs, original.logs);
        expect(retrieved.createdAt.millisecondsSinceEpoch, original.createdAt.millisecondsSinceEpoch);
        expect(retrieved.completedAt?.millisecondsSinceEpoch, original.completedAt?.millisecondsSinceEpoch);
      });

      test('U-DL-HDB-25: Handle null completedAt column', () async {
        await db.insertEntry(createDummyEntry('1'));
        final retrieved = (await db.getEntry('1'))!;
        expect(retrieved.completedAt, isNull);
      });

      test('U-DL-HDB-26: Handle null errorMessage column', () async {
        await db.insertEntry(createDummyEntry('1'));
        final retrieved = (await db.getEntry('1'))!;
        expect(retrieved.errorMessage, isNull);
      });
    });
  });
}
