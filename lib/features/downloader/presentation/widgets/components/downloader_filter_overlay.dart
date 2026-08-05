import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';

class DownloaderFilterOverlay {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required Offset position,
    required DownloaderFilterSettings initialSettings,
    required Set<DownloaderItemType> availableTypes,
    required Set<DateTime> availableDates,
    required ValueChanged<DownloaderFilterSettings> onFilterChanged,
    Map<DownloaderItemType, Set<DateTime>> availableDatesByType = const {},
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _DownloaderFilterOverlayPopup(
        position: position,
        initialSettings: initialSettings,
        availableTypes: availableTypes,
        availableDates: availableDates,
        onFilterChanged: onFilterChanged,
        onClose: hide,
        availableDatesByType: availableDatesByType,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _DownloaderFilterOverlayPopup extends StatelessWidget {
  const _DownloaderFilterOverlayPopup({
    required this.position,
    required this.initialSettings,
    required this.availableTypes,
    required this.availableDates,
    required this.onFilterChanged,
    required this.onClose,
    this.availableDatesByType = const {},
  });

  final Offset position;
  final DownloaderFilterSettings initialSettings;
  final Set<DownloaderItemType> availableTypes;
  final Set<DateTime> availableDates;
  final Map<DownloaderItemType, Set<DateTime>> availableDatesByType;
  final ValueChanged<DownloaderFilterSettings> onFilterChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const width = 380.0;
    var left = position.dx - width + 40;
    final top = position.dy + 48;

    if (left < 16) left = 16;
    if (left + width > screenSize.width - 16) {
      left = screenSize.width - width - 16;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              constraints: BoxConstraints(maxHeight: screenSize.height * 0.85),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: DownloaderFilterOverlayWidget(
                  initialSettings: initialSettings,
                  availableTypes: availableTypes,
                  availableDates: availableDates,
                  availableDatesByType: availableDatesByType,
                  onFilterChanged: onFilterChanged,
                  onClose: onClose,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DownloaderFilterOverlayWidget extends StatefulWidget {
  const DownloaderFilterOverlayWidget({
    required this.initialSettings,
    required this.availableTypes,
    required this.availableDates,
    required this.onFilterChanged,
    required this.onClose,
    this.availableDatesByType = const {},
    super.key,
  });

  final DownloaderFilterSettings initialSettings;
  final Set<DownloaderItemType> availableTypes;
  final Set<DateTime> availableDates;
  final Map<DownloaderItemType, Set<DateTime>> availableDatesByType;
  final ValueChanged<DownloaderFilterSettings> onFilterChanged;
  final VoidCallback onClose;

  @override
  State<DownloaderFilterOverlayWidget> createState() =>
      _DownloaderFilterOverlayWidgetState();
}

class _DownloaderFilterOverlayWidgetState
    extends State<DownloaderFilterOverlayWidget> {
  late DownloaderFilterSettings _settings;
  bool _isDateAccordionExpanded = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    // Auto-expand accordion if dates are already filtered
    if (_settings.selectedDates.isNotEmpty) {
      _isDateAccordionExpanded = true;
    }
  }

  Set<DateTime> get _effectiveAvailableDates {
    if (_settings.selectedTypes.isEmpty) {
      return widget.availableDates;
    }
    if (widget.availableDatesByType.isEmpty) {
      return widget.availableDates;
    }
    final dates = <DateTime>{};
    for (final type in _settings.selectedTypes) {
      final typeDates = widget.availableDatesByType[type];
      if (typeDates != null) {
        dates.addAll(typeDates);
      }
    }
    return dates;
  }

  void _updateSettings(DownloaderFilterSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onFilterChanged(newSettings);
  }

  void _toggleType(DownloaderItemType type) {
    final updatedTypes = Set<DownloaderItemType>.from(_settings.selectedTypes);
    if (updatedTypes.contains(type)) {
      updatedTypes.remove(type);
    } else {
      updatedTypes.add(type);
    }

    final newEffectiveDates = <DateTime>{};
    if (updatedTypes.isEmpty) {
      newEffectiveDates.addAll(widget.availableDates);
    } else if (widget.availableDatesByType.isNotEmpty) {
      for (final t in updatedTypes) {
        final tDates = widget.availableDatesByType[t];
        if (tDates != null) {
          newEffectiveDates.addAll(tDates);
        }
      }
    } else {
      newEffectiveDates.addAll(widget.availableDates);
    }

    final updatedDates = _settings.selectedDates.where((selected) {
      return newEffectiveDates.any((avail) =>
          avail.year == selected.year &&
          avail.month == selected.month &&
          avail.day == selected.day);
    }).toSet();

    _updateSettings(
      _settings.copyWith(
        selectedTypes: updatedTypes,
        selectedDates: updatedDates,
      ),
    );
  }

  void _onDatesChanged(Set<DateTime> dates) {
    _updateSettings(_settings.copyWith(selectedDates: dates));
  }

  void _resetAll() {
    _updateSettings(const DownloaderFilterSettings());
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = !_settings.isDefault;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.violet,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Filter',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Reset Button
              InkWell(
                onTap: hasActiveFilters ? _resetAll : null,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: hasActiveFilters ? AppColors.violet : Colors.white24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reset',
                        style: GoogleFonts.manrope(
                          color: hasActiveFilters ? AppColors.violet : Colors.white24,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Close button
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white60,
                  size: 18,
                ),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Types Section Header
          Text(
            'TYPES',
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // 3-Row Grid (2 columns per row)
          _buildTypeGrid(),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),

          // Date Filter Accordion
          _buildDateAccordion(),
        ],
      ),
    ),
    );
  }

  Widget _buildTypeGrid() {
    const rows = [
      [DownloaderItemType.image, DownloaderItemType.video],
      [DownloaderItemType.groupPost, DownloaderItemType.playlist],
      [DownloaderItemType.profile, DownloaderItemType.others],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: _buildTypeCheckbox(row[0])),
              const SizedBox(width: 8),
              Expanded(child: _buildTypeCheckbox(row[1])),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForType(DownloaderItemType type) {
    switch (type) {
      case DownloaderItemType.image:
        return Icons.image_outlined;
      case DownloaderItemType.video:
        return Icons.videocam_outlined;
      case DownloaderItemType.groupPost:
        return Icons.collections_outlined;
      case DownloaderItemType.playlist:
        return Icons.queue_music_rounded;
      case DownloaderItemType.profile:
        return Icons.person_outline_rounded;
      case DownloaderItemType.others:
        return Icons.category_outlined;
    }
  }

  Widget _buildTypeCheckbox(DownloaderItemType type) {
    final isAvailable = widget.availableTypes.contains(type);
    final isSelected = _settings.selectedTypes.contains(type);

    return InkWell(
      onTap: isAvailable ? () => _toggleType(type) : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.violet.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.violet.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.3,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : Colors.white30,
                    width: 1.5,
                  ),
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check_rounded, color: Colors.white, size: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Icon(
                _iconForType(type),
                size: 15,
                color: isSelected ? AppColors.violet : Colors.white70,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  type.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateAccordion() {
    final hasDates = _settings.selectedDates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isDateAccordionExpanded = !_isDateAccordionExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: hasDates ? AppColors.violet : Colors.white60,
                ),
                const SizedBox(width: 8),
                Text(
                  'UPLOADED DATE',
                  style: GoogleFonts.manrope(
                    color: hasDates ? Colors.white : Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                if (hasDates) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.violet.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_settings.selectedDates.length}',
                      style: GoogleFonts.manrope(
                        color: AppColors.violet,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: _isDateAccordionExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isDateAccordionExpanded) ...[
          const SizedBox(height: 10),
          DownloaderFilterCalendar(
            selectedDates: _settings.selectedDates,
            availableDates: _effectiveAvailableDates,
            onDatesChanged: _onDatesChanged,
          ),
        ],
      ],
    );
  }
}

class DownloaderFilterCalendar extends StatefulWidget {
  const DownloaderFilterCalendar({
    required this.selectedDates,
    required this.availableDates,
    required this.onDatesChanged,
    super.key,
  });

  final Set<DateTime> selectedDates;
  final Set<DateTime> availableDates;
  final ValueChanged<Set<DateTime>> onDatesChanged;

  @override
  State<DownloaderFilterCalendar> createState() =>
      _DownloaderFilterCalendarState();
}

class _DownloaderFilterCalendarState extends State<DownloaderFilterCalendar> {
  late DateTime _viewDate;
  DateTime? _anchorDate;

  @override
  void initState() {
    super.initState();
    if (widget.selectedDates.isNotEmpty) {
      _viewDate = widget.selectedDates.first;
    } else if (widget.availableDates.isNotEmpty) {
      _viewDate = widget.availableDates.first;
    } else {
      _viewDate = DateTime.now();
    }
  }

  @override
  void didUpdateWidget(DownloaderFilterCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availableDates.isNotEmpty) {
      final hasDateInCurrentMonth = widget.availableDates.any(
        (d) => d.year == _viewDate.year && d.month == _viewDate.month,
      );
      if (!hasDateInCurrentMonth) {
        setState(() {
          _viewDate = widget.availableDates.first;
        });
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _getDaysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;
  int _getPrevMonthDays(DateTime date) =>
      DateTime(date.year, date.month, 0).day;

  String _formatMonthYear(DateTime date) {
    const months = [
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

  void _handleDateTap(DateTime date) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    final isControl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);

    final newDates = Set<DateTime>.from(widget.selectedDates);
    final normalized = DateTime(date.year, date.month, date.day);

    if (isShift && _anchorDate != null) {
      final start = _anchorDate!.isBefore(normalized) ? _anchorDate! : normalized;
      final end = _anchorDate!.isBefore(normalized) ? normalized : _anchorDate!;

      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        final dNorm = DateTime(d.year, d.month, d.day);
        // Only select available dates
        if (widget.availableDates.isEmpty ||
            widget.availableDates.any((ad) => _isSameDay(ad, dNorm))) {
          newDates.add(dNorm);
        }
      }
    } else if (isControl) {
      if (newDates.any((d) => _isSameDay(d, normalized))) {
        newDates.removeWhere((d) => _isSameDay(d, normalized));
      } else {
        newDates.add(normalized);
      }
      _anchorDate = normalized;
    } else {
      // Single click: toggle date
      if (newDates.any((d) => _isSameDay(d, normalized))) {
        newDates.removeWhere((d) => _isSameDay(d, normalized));
      } else {
        newDates.add(normalized);
      }
      _anchorDate = normalized;
    }

    widget.onDatesChanged(newDates);
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month Navigation
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: Colors.white60,
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
                color: Colors.white60,
              ),
              onPressed: () => setState(
                () => _viewDate = DateTime(_viewDate.year, _viewDate.month + 1),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Reset dates button
            Opacity(
              opacity: hasSelection ? 1.0 : 0.3,
              child: IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: hasSelection ? AppColors.violet : Colors.white30,
                ),
                onPressed: hasSelection ? () => widget.onDatesChanged({}) : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Reset Dates',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Day of week labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) {
            return SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.manrope(
                    color: Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),

        // Calendar Grid
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
            final isAvailable =
                widget.availableDates.any((d) => _isSameDay(d, normalizedDate));

            return InkWell(
              onTap: isAvailable ? () => _handleDateTap(normalizedDate) : null,
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: !isSelected && isToday
                      ? AppColors.violet.withValues(alpha: 0.1)
                      : (isSelected ? null : Colors.transparent),
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isSelected
                      ? Border.all(
                          color: AppColors.violet.withValues(alpha: 0.3),
                          width: 0.8,
                        )
                      : null,
                ),
                child: Text(
                  date.day.toString(),
                  style: GoogleFonts.manrope(
                    color: !isAvailable
                        ? Colors.white.withValues(alpha: 0.08)
                        : (isSelected
                            ? Colors.white
                            : (currentMonth ? Colors.white70 : Colors.white24)),
                    fontSize: 11,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : (isAvailable ? FontWeight.w500 : FontWeight.normal),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
