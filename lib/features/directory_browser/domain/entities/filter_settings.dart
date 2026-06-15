import 'package:equatable/equatable.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class FilterSettings extends Equatable {
  final Set<DateTime>? selectedDates; // null = any
  final bool?
  foldersOnly; // null = both, true = folders only, false = files only
  final FileItemType? category;
  final Set<String> extensions;

  const FilterSettings({
    this.selectedDates,
    this.foldersOnly,
    this.category,
    this.extensions = const {},
  });

  bool get isEmpty =>
      selectedDates == null &&
      foldersOnly == null &&
      category == null &&
      extensions.isEmpty;

  @override
  List<Object?> get props => [selectedDates, foldersOnly, category, extensions];

  FilterSettings copyWith({
    Set<DateTime>? selectedDates,
    bool? foldersOnly,
    FileItemType? category,
    Set<String>? extensions,
    bool clearDates = false,
    bool clearFoldersOnly = false,
    bool clearCategory = false,
  }) {
    return FilterSettings(
      selectedDates: clearDates ? null : (selectedDates ?? this.selectedDates),
      foldersOnly: clearFoldersOnly ? null : (foldersOnly ?? this.foldersOnly),
      category: clearCategory ? null : (category ?? this.category),
      extensions: extensions ?? this.extensions,
    );
  }

  List<FileItem> apply(List<FileItem> items) {
    if (isEmpty) return items;

    return items.where((item) {
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
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
