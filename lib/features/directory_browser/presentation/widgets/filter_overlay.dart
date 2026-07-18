import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';

class FilterOverlay {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required Offset position,
    required FilterSettings initialSettings,
    required void Function(FilterSettings) onSelected,
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _FilterOverlayWidget(
        position: position,
        initialSettings: initialSettings,
        onApply: (settings) {
          hide();
          onSelected(settings);
        },
        onClose: hide,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _FilterOverlayWidget extends StatefulWidget {

  const _FilterOverlayWidget({
    required this.position,
    required this.initialSettings,
    required this.onApply,
    required this.onClose,
  });
  final Offset position;
  final FilterSettings initialSettings;
  final void Function(FilterSettings) onApply;
  final VoidCallback onClose;

  @override
  State<_FilterOverlayWidget> createState() => _FilterOverlayWidgetState();
}

class _FilterOverlayWidgetState extends State<_FilterOverlayWidget> {
  late FilterSettings _settings;
  String? _expandedSection;
  final Map<String, LayerLink> _layerLinks = {
    'itemType': LayerLink(),
    'fileType': LayerLink(),
  };
  OverlayEntry? _dropdownEntry;
  String? _errorMessage;

  Timer? _errorTimer;

  @override
  void dispose() {
    _errorTimer?.cancel();
    _dropdownEntry?.remove();
    _dropdownEntry = null;
    super.dispose();
  }

  void _hideDropdown() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
    if (mounted && _expandedSection != null) {
      setState(() => _expandedSection = null);
    }
  }

  void _showDropdown<T>({
    required String sectionId,
    required T value,
    required List<DropdownMenuItemData<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    _hideDropdown();
    setState(() => _expandedSection = sectionId);

    _dropdownEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideDropdown,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLinks[sectionId]!,
            showWhenUnlinked: false,
            offset: const Offset(0, 52), // Height of selector + gap
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 360, // Match interior width (400 - 40 padding)
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((item) {
                    final isSelected = item.value == value;
                    return InkWell(
                      onTap: () {
                        onChanged(item.value);
                        _hideDropdown();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Text(
                              item.label,
                              style: GoogleFonts.manrope(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            _buildRadioButton(isSelected),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_dropdownEntry!);
  }

  Widget _buildCheckbox(bool isSelected) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.white24,
          width: 1.5,
        ),
        gradient: isSelected ? AppTheme.primaryGradient : null,
      ),
      child: isSelected
          ? const Center(
              child: Icon(Icons.check_rounded, color: Colors.white, size: 12),
            )
          : null,
    );
  }

  Widget _buildRadioButton(bool isSelected) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.white24,
          width: 1.5,
        ),
        gradient: isSelected ? AppTheme.primaryGradient : null,
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const width = 400.0;
    final maxHeight =
        screenSize.height * 0.8; // Allow up to 80% of screen height

    var left = widget.position.dx - width + 40;
    final top = widget.position.dy + 48;

    if (left < 16) left = 16;
    if (left + width > screenSize.width - 16) {
      left = screenSize.width - width - 16;
    }

    // If the box might go off-screen at the bottom, we cap its height
    // and potentially shift it up.
    final availableHeight = screenSize.height - top - 16;
    if (availableHeight < 400 && widget.position.dy > screenSize.height / 2) {
      // Near bottom, grow upwards instead
      return Stack(
        children: [
          _buildBackdrop(widget.onClose),
          Positioned(
            left: left,
            bottom: screenSize.height - widget.position.dy + 8,
            child: _buildContent(width, maxHeight),
          ),
        ],
      );
    }

    return Stack(
      children: [
        _buildBackdrop(widget.onClose),
        Positioned(
          left: left,
          top: top,
          child: _buildContent(width, availableHeight.clamp(400.0, maxHeight)),
        ),
      ],
    );
  }

  Widget _buildBackdrop(VoidCallback onTap) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildContent(double width, double maxHeight) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: width,
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('DATE RANGE'),
                        _buildCalendarSection(),
                        const SizedBox(height: 24),

                        _buildSectionTitle('ITEM TYPE'),
                        _buildItemTypeDropdown(),

                        if (_settings.foldersOnly == false) ...[
                          const SizedBox(height: 24),
                          _buildSectionTitle('FILE TYPE'),
                          _buildFileTypeDropdown(),

                          if (_settings.category != null) ...[
                            const SizedBox(height: 24),
                            _buildSectionTitle(
                              'FILE EXTENSION',
                              trailing: _buildSelectAllCheckbox(),
                            ),
                            _buildExtensionDropdown(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.violet,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Advanced Filters',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              color: Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: FilterCalendar(
        selectedDates: _settings.selectedDates ?? {},
        onDatesChanged: (dates) {
          setState(() {
            _settings = _settings.copyWith(
              selectedDates: dates,
              clearDates: dates.isEmpty,
            );
          });
        },
      ),
    );
  }

  Widget _buildItemTypeDropdown() {
    final val = _settings.foldersOnly;
    final label = val == null ? 'Any' : (val ? 'Folders' : 'Files');

    return _buildCustomSelector<bool?>(
      sectionId: 'itemType',
      label: label,
      value: val,
      items: [
        DropdownMenuItemData(label: 'Any', value: null),
        DropdownMenuItemData(label: 'Folders', value: true),
        DropdownMenuItemData(label: 'Files', value: false),
      ],
      onChanged: (newVal) {
        setState(() {
          _settings = _settings.copyWith(
            foldersOnly: newVal,
            clearFoldersOnly: newVal == null,
            clearCategory: true,
            extensions: {},
          );
          _expandedSection = null;
        });
      },
    );
  }

  Widget _buildFileTypeDropdown() {
    final cat = _settings.category;
    final label = cat == null
        ? 'Any'
        : (cat.name[0].toUpperCase() + cat.name.substring(1));
    final categories = FileItemType.values
        .where((e) => e != FileItemType.folder)
        .toList();

    return _buildCustomSelector<FileItemType?>(
      sectionId: 'fileType',
      label: label,
      value: cat,
      items: [
        DropdownMenuItemData(label: 'Any', value: null),
        ...categories.map(
          (c) => DropdownMenuItemData(
            label: c.name[0].toUpperCase() + c.name.substring(1),
            value: c,
          ),
        ),
      ],
      onChanged: (newVal) {
        setState(() {
          _settings = _settings.copyWith(
            category: newVal,
            clearCategory: newVal == null,
            extensions: {}, // Don't check by default
          );
          _expandedSection = null;
          _errorMessage = null;
          _errorTimer?.cancel();
        });
      },
    );
  }

  Widget _buildCustomSelector<T>({
    required String sectionId,
    required String label,
    required T value,
    required List<DropdownMenuItemData<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    final isExpanded = _expandedSection == sectionId;

    return CompositedTransformTarget(
      link: _layerLinks[sectionId]!,
      child: GestureDetector(
        onTap: () {
          if (isExpanded) {
            _hideDropdown();
          } else {
            _showDropdown<T>(
              sectionId: sectionId,
              value: value,
              items: items,
              onChanged: onChanged,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpanded
                  ? AppColors.violet.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white30,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectAllCheckbox() {
    final cat = _settings.category;
    if (cat == null) return const SizedBox.shrink();

    final exts = FileTypeClassifier.getExtensionsForType(cat);
    final allSelected = exts.every((e) => _settings.extensions.contains(e));

    return GestureDetector(
      onTap: () {
        setState(() {
          if (allSelected) {
            _settings = _settings.copyWith(extensions: {});
          } else {
            _settings = _settings.copyWith(extensions: Set.from(exts));
          }
          _errorMessage = null;
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCheckbox(allSelected),
            const SizedBox(width: 8),
            Text(
              'Select All',
              style: GoogleFonts.manrope(
                color: allSelected ? Colors.white70 : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtensionDropdown() {
    final cat = _settings.category!;
    final exts = FileTypeClassifier.getExtensionsForType(cat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: exts.map((ext) {
            final isSelected = _settings.extensions.contains(ext);
            return _buildSelectableChip(
              label: ext,
              isSelected: isSelected,
              small: true,
              onTap: () {
                final newExts = Set<String>.from(_settings.extensions);
                if (isSelected) {
                  newExts.remove(ext);
                } else {
                  newExts.add(ext);
                }
                setState(() {
                  _settings = _settings.copyWith(extensions: newExts);
                  _errorMessage = null;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool small = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 14,
          vertical: small ? 6 : 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: small ? 11 : 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.manrope(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _settings = const FilterSettings();
                    _errorMessage = null;
                  });
                },
                child: Text(
                  'Reset',
                  style: GoogleFonts.manrope(
                    color: Colors.white30,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onClose,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_settings.category != null &&
                      _settings.extensions.isEmpty) {
                    setState(() {
                      _errorMessage = 'At least one extension must be selected';
                    });

                    _errorTimer?.cancel();
                    _errorTimer = Timer(const Duration(seconds: 2), () {
                      if (mounted) {
                        setState(() => _errorMessage = null);
                      }
                    });
                    return;
                  }
                  widget.onApply(_settings);
                },
                style:
                    ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ).copyWith(
                      elevation: WidgetStateProperty.all(0),
                    ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Apply Filter',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DropdownMenuItemData<T> {
  DropdownMenuItemData({required this.label, required this.value});
  final String label;
  final T value;
}

class FilterCalendar extends StatefulWidget {

  const FilterCalendar({
    required this.selectedDates, required this.onDatesChanged, super.key,
  });
  final Set<DateTime> selectedDates;
  final ValueChanged<Set<DateTime>> onDatesChanged;

  @override
  State<FilterCalendar> createState() => _FilterCalendarState();
}

class _FilterCalendarState extends State<FilterCalendar> {
  late DateTime _viewDate;
  DateTime? _anchorDate;

  @override
  void initState() {
    super.initState();
    _viewDate = widget.selectedDates.isNotEmpty
        ? widget.selectedDates.first
        : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final monthDays = _getDaysInMonth(_viewDate);
    final prevMonthDays = _getPrevMonthDays(_viewDate);
    final firstDayOfWeek =
        DateTime(_viewDate.year, _viewDate.month).weekday % 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hasSelection = widget.selectedDates.isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: Colors.white30,
              ),
              onPressed: () => setState(
                () => _viewDate = DateTime(_viewDate.year, _viewDate.month - 1),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _formatMonthYear(_viewDate),
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white30,
              ),
              onPressed:
                  _viewDate.year < now.year ||
                      (_viewDate.year == now.year &&
                          _viewDate.month < now.month)
                  ? () => setState(
                      () => _viewDate = DateTime(
                        _viewDate.year,
                        _viewDate.month + 1,
                      ),
                    )
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Calendar Reset Button
            Opacity(
              opacity: hasSelection ? 1.0 : 0.3,
              child: IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: hasSelection ? AppColors.violet : Colors.white30,
                ),
                onPressed: hasSelection
                    ? () => widget.onDatesChanged({})
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Reset Dates',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            DateTime date;
            var currentMonth = true;
            if (index < firstDayOfWeek) {
              date = DateTime(
                _viewDate.year,
                _viewDate.month - 1,
                prevMonthDays - firstDayOfWeek + index + 1,
              );
              currentMonth = false;
            } else if (index < firstDayOfWeek + monthDays) {
              date = DateTime(
                _viewDate.year,
                _viewDate.month,
                index - firstDayOfWeek + 1,
              );
            } else {
              date = DateTime(
                _viewDate.year,
                _viewDate.month + 1,
                index - firstDayOfWeek - monthDays + 1,
              );
              currentMonth = false;
            }

            final normalizedDate = DateTime(date.year, date.month, date.day);
            final isSelected = widget.selectedDates.any(
              (d) => _isSameDay(d, normalizedDate),
            );
            final isToday = _isSameDay(today, normalizedDate);
            final isFuture = normalizedDate.isAfter(today);

            return InkWell(
              onTap: isFuture ? null : () => _handleDateTap(normalizedDate),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: !isSelected && isToday
                      ? AppColors.violet.withValues(alpha: 0.1)
                      : (isSelected ? null : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday && !isSelected
                      ? Border.all(
                          color: AppColors.violet.withValues(alpha: 0.2),
                          width: 0.5,
                        )
                      : null,
                ),
                child: Text(
                  date.day.toString(),
                  style: GoogleFonts.manrope(
                    color: isFuture
                        ? Colors.white.withValues(alpha: 0.05)
                        : (isSelected
                              ? Colors.white
                              : (currentMonth
                                    ? Colors.white70
                                    : Colors.white12)),
                    fontSize: 11,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _handleDateTap(DateTime date) {
    final isShift =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );

    final newDates = Set<DateTime>.from(widget.selectedDates);

    if (isShift && _anchorDate != null) {
      final start = _anchorDate!.isBefore(date) ? _anchorDate! : date;
      final end = _anchorDate!.isBefore(date) ? date : _anchorDate!;
      for (
        var d = start;
        d.isBefore(end.add(const Duration(days: 1)));
        d = d.add(const Duration(days: 1))
      ) {
        newDates.add(DateTime(d.year, d.month, d.day));
      }
    } else {
      final normalized = DateTime(date.year, date.month, date.day);
      if (newDates.any((d) => _isSameDay(d, normalized))) {
        newDates.removeWhere((d) => _isSameDay(d, normalized));
      } else {
        newDates.add(normalized);
      }
      _anchorDate = normalized;
    }

    widget.onDatesChanged(newDates);
  }

  int _getDaysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;
  int _getPrevMonthDays(DateTime date) =>
      DateTime(date.year, date.month, 0).day;
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _formatMonthYear(DateTime date) {
    final months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
