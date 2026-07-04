import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  group('FilterSettings', () {
    final tDate = DateTime(2023, 1, 1);
    
    final itemToday = FileItem(
      path: '/today.txt',
      name: 'today.txt',
      type: FileItemType.document,
      modified: tDate,
    );
    final itemYesterday = FileItem(
      path: '/yesterday.jpg',
      name: 'yesterday.jpg',
      type: FileItemType.image,
      modified: DateTime(2022, 12, 31),
    );
    final folderToday = FileItem(
      path: '/folder',
      name: 'folder',
      type: FileItemType.folder,
      modified: tDate,
    );
    final allItems = [itemToday, itemYesterday, folderToday];

    test('isEmpty returns true when all fields are null or empty', () {
      const emptySettings = FilterSettings();
      expect(emptySettings.isEmpty, isTrue);
    });

    test('isEmpty returns false when at least one field is set', () {
      expect(const FilterSettings(selectedDates: {}).isEmpty, isFalse);
      expect(const FilterSettings(foldersOnly: true).isEmpty, isFalse);
      expect(const FilterSettings(category: FileItemType.image).isEmpty, isFalse);
      expect(const FilterSettings(extensions: {'.jpg'}).isEmpty, isFalse);
    });

    test('supports value equality (Equatable)', () {
      final s1 = FilterSettings(
        selectedDates: {tDate},
        foldersOnly: false,
        category: FileItemType.document,
        extensions: const {'.pdf'},
      );
      final s2 = FilterSettings(
        selectedDates: {tDate},
        foldersOnly: false,
        category: FileItemType.document,
        extensions: const {'.pdf'},
      );
      final s3 = const FilterSettings();

      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
    });

    test('copyWith updates and clears fields correctly', () {
      final settings = FilterSettings(
        selectedDates: {tDate},
        foldersOnly: true,
        category: FileItemType.video,
        extensions: const {'.mp4'},
      );

      final updated = settings.copyWith(
        selectedDates: {DateTime(2024)},
        foldersOnly: false,
        category: FileItemType.audio,
        extensions: const {'.mp3'},
      );

      expect(updated.selectedDates, {DateTime(2024)});
      expect(updated.foldersOnly, false);
      expect(updated.category, FileItemType.audio);
      expect(updated.extensions, const {'.mp3'});

      final cleared = updated.copyWith(
        clearDates: true,
        clearFoldersOnly: true,
        clearCategory: true,
        extensions: const {},
      );

      expect(cleared.isEmpty, isTrue);
    });

    test('copyWith retains old values if null is passed', () {
      final settings = FilterSettings(
        selectedDates: {tDate},
        foldersOnly: true,
        category: FileItemType.video,
        extensions: const {'.mp4'},
      );
      
      final updated = settings.copyWith();

      expect(updated.selectedDates, {tDate});
      expect(updated.foldersOnly, true);
      expect(updated.category, FileItemType.video);
      expect(updated.extensions, const {'.mp4'});
    });

    test('apply() returns all items if isEmpty is true', () {
      const settings = FilterSettings();
      expect(settings.apply(allItems), allItems);
    });

    test('apply() filters by date', () {
      final settings = FilterSettings(selectedDates: {tDate});
      final filtered = settings.apply(allItems);
      
      expect(filtered.length, 2);
      expect(filtered, contains(itemToday));
      expect(filtered, contains(folderToday));
    });

    test('apply() filters by foldersOnly = true', () {
      const settings = FilterSettings(foldersOnly: true);
      final filtered = settings.apply(allItems);
      
      expect(filtered.length, 1);
      expect(filtered.first, folderToday);
    });

    test('apply() filters by foldersOnly = false (files only)', () {
      const settings = FilterSettings(foldersOnly: false);
      final filtered = settings.apply(allItems);
      
      expect(filtered.length, 2);
      expect(filtered, contains(itemToday));
      expect(filtered, contains(itemYesterday));
    });

    test('apply() filters by category (ignoring folders unless foldersOnly is true)', () {
      // category filters out folders unless foldersOnly is exactly true
      const settings = FilterSettings(category: FileItemType.image);
      final filtered = settings.apply(allItems);
      
      expect(filtered.length, 1);
      expect(filtered.first, itemYesterday);
    });

    test('apply() includes folders when category is set but foldersOnly = true', () {
      const settings = FilterSettings(category: FileItemType.image, foldersOnly: true);
      final filtered = settings.apply(allItems);
      
      // when foldersOnly is true, only folders should remain. The category filter for folders passes when foldersOnly is true.
      expect(filtered.length, 1);
      expect(filtered.first, folderToday);
    });

    test('apply() filters by extensions', () {
      const settings = FilterSettings(extensions: {'.jpg'});
      final filtered = settings.apply(allItems);
      
      // extensions don't filter folders, only files
      expect(filtered.length, 2);
      expect(filtered, contains(itemYesterday)); // file matching extension
      expect(filtered, contains(folderToday)); // folder should be included
    });

    test('apply() combining multiple filters', () {
      final settings = FilterSettings(
        selectedDates: {DateTime(2022, 12, 31)}, // Only yesterday
        extensions: {'.jpg'}, // Only .jpg
      );
      final filtered = settings.apply(allItems);
      
      // Folder doesn't match date, today.txt doesn't match date or ext
      expect(filtered.length, 1);
      expect(filtered.first, itemYesterday);
    });
  });
}

