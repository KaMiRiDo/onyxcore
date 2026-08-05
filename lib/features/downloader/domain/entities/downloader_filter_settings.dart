import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

enum DownloaderItemType {
  image('Image'),
  video('Videos'),
  groupPost('Group Post'),
  playlist('Playlist'),
  profile('Profile'),
  others('Others');

  const DownloaderItemType(this.label);
  final String label;
}

@immutable
class DownloaderFilterSettings {
  const DownloaderFilterSettings({
    this.selectedTypes = const {},
    this.selectedDates = const {},
  });

  final Set<DownloaderItemType> selectedTypes;
  final Set<DateTime> selectedDates;

  bool get isDefault => selectedTypes.isEmpty && selectedDates.isEmpty;

  DownloaderFilterSettings copyWith({
    Set<DownloaderItemType>? selectedTypes,
    Set<DateTime>? selectedDates,
  }) {
    return DownloaderFilterSettings(
      selectedTypes: selectedTypes ?? this.selectedTypes,
      selectedDates: selectedDates ?? this.selectedDates,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloaderFilterSettings &&
        setEquals(other.selectedTypes, selectedTypes) &&
        setEquals(other.selectedDates, selectedDates);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(selectedTypes),
        Object.hashAll(selectedDates),
      );
}

@immutable
class DownloaderViewPreferences {
  const DownloaderViewPreferences({
    this.sortOrder = 'added_desc',
    this.filterSettings = const DownloaderFilterSettings(),
  });

  final String sortOrder;
  final DownloaderFilterSettings filterSettings;

  DownloaderViewPreferences copyWith({
    String? sortOrder,
    DownloaderFilterSettings? filterSettings,
  }) {
    return DownloaderViewPreferences(
      sortOrder: sortOrder ?? this.sortOrder,
      filterSettings: filterSettings ?? this.filterSettings,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloaderViewPreferences &&
        other.sortOrder == sortOrder &&
        other.filterSettings == filterSettings;
  }

  @override
  int get hashCode => Object.hash(sortOrder, filterSettings);
}

class DownloaderItemClassifier {
  static DownloaderItemType classify(dynamic item) {
    if (item is MediaGroup) return classifyGroup(item);
    if (item is MediaInfo) return classifyItem(item);
    return DownloaderItemType.others;
  }

  static DownloaderItemType classifyGroup(MediaGroup group) {
    if (group.items.isEmpty) return DownloaderItemType.others;
    final first = group.first;
    if (first.isProfile) return DownloaderItemType.profile;
    if (first.isPlaylist) return DownloaderItemType.playlist;
    if (group.items.length > 1) return DownloaderItemType.groupPost;
    if (first.isVideo) return DownloaderItemType.video;
    return DownloaderItemType.image;
  }

  static DownloaderItemType classifyItem(MediaInfo info) {
    if (info.isProfile) return DownloaderItemType.profile;
    if (info.isPlaylist) return DownloaderItemType.playlist;
    if (info.isVideo) return DownloaderItemType.video;
    return DownloaderItemType.image;
  }

  static DateTime? extractDate(dynamic item) {
    DateTime? rawDate;
    if (item is MediaGroup) {
      if (item.items.isNotEmpty) {
        rawDate = item.first.uploadDate;
      }
    } else if (item is MediaInfo) {
      rawDate = item.uploadDate;
    }
    if (rawDate == null) return null;
    return DateTime(rawDate.year, rawDate.month, rawDate.day);
  }

  static bool matchesDateFilter(MediaGroup group, Set<DateTime> selectedDates) {
    if (selectedDates.isEmpty) return true;
    for (final item in group.items) {
      final date = item.uploadDate;
      if (date != null) {
        final d = DateTime(date.year, date.month, date.day);
        if (selectedDates.any((sd) =>
            sd.year == d.year && sd.month == d.month && sd.day == d.day)) {
          return true;
        }
      }
    }
    return false;
  }
}
