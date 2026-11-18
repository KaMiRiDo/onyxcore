import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/broken_media_detector.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

class FilterSettings extends Equatable {
  const FilterSettings({
    this.selectedDates,
    this.foldersOnly,
    this.category,
    this.extensions = const {},
    this.brokenOnly = false,
  });
  final Set<DateTime>? selectedDates; // null = any
  final bool?
  foldersOnly; // null = both, true = folders only, false = files only
  final FileItemType? category;
  final Set<String> extensions;
  final bool brokenOnly;

  bool get isEmpty =>
      selectedDates == null &&
      foldersOnly == null &&
      category == null &&
      extensions.isEmpty &&
      !brokenOnly;

  @override
  List<Object?> get props => [
    selectedDates,
    foldersOnly,
    category,
    extensions,
    brokenOnly,
  ];

  FilterSettings copyWith({
    Set<DateTime>? selectedDates,
    bool? foldersOnly,
    FileItemType? category,
    Set<String>? extensions,
    bool? brokenOnly,
    bool clearDates = false,
    bool clearFoldersOnly = false,
    bool clearCategory = false,
    bool clearBrokenOnly = false,
  }) {
    return FilterSettings(
      selectedDates: clearDates ? null : (selectedDates ?? this.selectedDates),
      foldersOnly: clearFoldersOnly ? null : (foldersOnly ?? this.foldersOnly),
      category: clearCategory ? null : (category ?? this.category),
      extensions: extensions ?? this.extensions,
      brokenOnly: !clearBrokenOnly && (brokenOnly ?? this.brokenOnly),
    );
  }

  List<FileItem> apply(
    List<FileItem> items, {
    ThumbnailCacheService? cacheService,
  }) {
    if (isEmpty) return items;

    final filtered = items.where((item) {
      // 0. Broken Items Filter
      if (brokenOnly) {
        if (!item.isBroken) {
          final exists = File(item.path).existsSync();
          if (!exists ||
              !BrokenMediaDetector.isBrokenSync(
                item.path,
                type: item.type,
                sizeBytes: item.sizeBytes,
                cacheService: cacheService,
              )) {
            return false;
          }
        }
      }

      // 1. Date Filter
      if (selectedDates != null && selectedDates!.isNotEmpty) {
        final itemDate = DateTime(
          item.modified.year,
          item.modified.month,
          item.modified.day,
        );
        if (!selectedDates!.any((d) => _isSameDay(d, itemDate))) return false;
      }

      // 2. Item Type Filter
      if (foldersOnly != null) {
        if (foldersOnly! && item.type != FileItemType.folder) return false;
        if (!foldersOnly! && item.type == FileItemType.folder) return false;
      }

      // 3. Category Filter
      if (category != null) {
        if (item.type == FileItemType.folder) {
          if (foldersOnly != true) return false;
        } else if (item.type != category) {
          return false;
        }
      }

      // 4. Extension Filter
      if (extensions.isNotEmpty && item.type != FileItemType.folder) {
        final ext = '.${item.name.split('.').last.toLowerCase()}';
        if (!extensions.contains(ext)) return false;
      }

      return true;
    });

    if (brokenOnly) {
      return filtered
          .map((item) => item.isBroken ? item : item.copyWith(isBroken: true))
          .toList();
    }
    return filtered.toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
