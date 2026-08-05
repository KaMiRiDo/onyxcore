// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

void main() {
  group('DownloaderFilterSettings Unit Tests', () {
    test('default settings has empty types and dates and isDefault is true', () {
      const settings = DownloaderFilterSettings();
      expect(settings.selectedTypes, isEmpty);
      expect(settings.selectedDates, isEmpty);
      expect(settings.isDefault, isTrue);
    });

    test('isDefault returns false when types or dates are populated', () {
      const typeSettings = DownloaderFilterSettings(
        selectedTypes: {DownloaderItemType.image},
      );
      expect(typeSettings.isDefault, isFalse);

      final dateSettings = DownloaderFilterSettings(
        selectedDates: {DateTime(2026, 8, 5)},
      );
      expect(dateSettings.isDefault, isFalse);
    });

    test('copyWith works correctly', () {
      const initial = DownloaderFilterSettings();
      final updated = initial.copyWith(
        selectedTypes: {DownloaderItemType.video, DownloaderItemType.playlist},
        selectedDates: {DateTime(2026, 8, 1)},
      );
      expect(updated.selectedTypes, {DownloaderItemType.video, DownloaderItemType.playlist});
      expect(updated.selectedDates, {DateTime(2026, 8, 1)});
    });

    test('equality and hashCode work as expected', () {
      final s1 = DownloaderFilterSettings(
        selectedTypes: {DownloaderItemType.image},
        selectedDates: {DateTime(2026, 8, 5)},
      );
      final s2 = DownloaderFilterSettings(
        selectedTypes: {DownloaderItemType.image},
        selectedDates: {DateTime(2026, 8, 5)},
      );
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
    });
  });

  group('DownloaderItemClassifier Unit Tests', () {
    test('classifies single image group as image', () {
      final item = MediaInfo(id: '1', title: 'Img', originalUrl: 'u', isVideo: false);
      final group = MediaGroup(originalUrl: 'u', items: [item]);
      expect(DownloaderItemClassifier.classifyGroup(group), DownloaderItemType.image);
    });

    test('classifies single video group as video', () {
      final item = MediaInfo(id: '2', title: 'Vid', originalUrl: 'u2', isVideo: true);
      final group = MediaGroup(originalUrl: 'u2', items: [item]);
      expect(DownloaderItemClassifier.classifyGroup(group), DownloaderItemType.video);
    });

    test('classifies multi-item group as groupPost', () {
      final item1 = MediaInfo(id: '3', title: 'P1', originalUrl: 'u3', isVideo: false);
      final item2 = MediaInfo(id: '4', title: 'P2', originalUrl: 'u3', isVideo: true);
      final group = MediaGroup(originalUrl: 'u3', items: [item1, item2]);
      expect(DownloaderItemClassifier.classifyGroup(group), DownloaderItemType.groupPost);
    });

    test('classifies playlist as playlist', () {
      final item = MediaInfo(id: '5', title: 'Play', originalUrl: 'u4', isPlaylist: true);
      final group = MediaGroup(originalUrl: 'u4', items: [item]);
      expect(DownloaderItemClassifier.classifyGroup(group), DownloaderItemType.playlist);
      expect(DownloaderItemClassifier.classifyItem(item), DownloaderItemType.playlist);
    });

    test('classifies profile as profile', () {
      final item = MediaInfo(id: '6', title: 'Prof', originalUrl: 'u5', isProfile: true);
      final group = MediaGroup(originalUrl: 'u5', items: [item]);
      expect(DownloaderItemClassifier.classifyGroup(group), DownloaderItemType.profile);
      expect(DownloaderItemClassifier.classifyItem(item), DownloaderItemType.profile);
    });

    test('extractDate normalizes to year, month, day', () {
      final dt = DateTime(2026, 8, 5, 14, 30, 45);
      final item = MediaInfo(id: '7', title: 'Dated', originalUrl: 'u6', uploadDate: dt);
      final group = MediaGroup(originalUrl: 'u6', items: [item]);

      expect(DownloaderItemClassifier.extractDate(group), DateTime(2026, 8, 5));
      expect(DownloaderItemClassifier.extractDate(item), DateTime(2026, 8, 5));
      expect(DownloaderItemClassifier.extractDate(MediaInfo(id: '8', title: 'No date', originalUrl: 'u7')), isNull);
    });
  });
}
