import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';

class ContextMenuItem {
  final String title;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final String? shortcut;
  final bool isDivider;
  final bool isEnabled;
  final bool isSelected;
  final List<ContextMenuItem>? subItems;

  const ContextMenuItem({
    required this.title,
    this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.shortcut,
    this.isDivider = false,
    this.isEnabled = true,
    this.isSelected = false,
    this.subItems,
  });

  factory ContextMenuItem.divider() {
    return ContextMenuItem(
      title: '',
      onTap: () {},
      isDivider: true,
    );
  }
}

class ContextMenu {
  static OverlayEntry? _overlayEntry;

  static void show(
    BuildContext context,
    Offset position,
    List<ContextMenuItem> items,
  ) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => _ContextMenuWidget(
        position: position,
        items: items,
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

class _ContextMenuWidget extends StatefulWidget {
  final Offset position;
  final List<ContextMenuItem> items;
  final VoidCallback onClose;
  final bool isSubmenu;

  const _ContextMenuWidget({
    required this.position,
    required this.items,
    required this.onClose,
    this.isSubmenu = false,
    this.onEnter,
    this.notchY,
  });

  final VoidCallback? onEnter;
  final double? notchY;

  @override
  State<_ContextMenuWidget> createState() => _ContextMenuWidgetState();
}

class _ContextMenuWidgetState extends State<_ContextMenuWidget> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double menuWidth = 240;
    // Estimate menu height: padding + (items * item height) + dividers
    final double menuHeight = 16 + (widget.items.length * 40);

    double left = widget.position.dx;
    double top = widget.position.dy;

    // Adjust position for screen boundaries
    if (left + menuWidth > screenSize.width) {
      if (widget.isSubmenu) {
        // If submenu, flip to the left of the parent
        left = widget.position.dx - (menuWidth * 2) + 16;
      } else {
        left = screenSize.width - menuWidth - 8;
      }
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 8;
    }
    if (left < 0) left = 8;
    if (top < 0) top = 8;

    return Stack(
      children: [
        // Full screen transparent overlay to close on tap outside (only for main menu)
        if (!widget.isSubmenu)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              onSecondaryTapDown: (_) => widget.onClose(),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),

        Positioned(
          left: left,
          top: top,
          child: MouseRegion(
            onEnter: (_) => widget.onEnter?.call(),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Notch indicator for submenus
                  if (widget.isSubmenu && widget.notchY != null)
                    Positioned(
                      left: -6,
                      top: widget.notchY!,
                      child: Transform.rotate(
                        angle: 0.785398, // 45 degrees
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E).withOpacity(0.85),
                            border: const Border(
                              left: BorderSide(color: Colors.white12),
                              bottom: BorderSide(color: Colors.white12),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // The Menu Container
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                        child: Container(
                          width: menuWidth,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF181818).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.items
                                .map(
                                  (item) => _ContextMenuItemWidget(
                                    item: item,
                                    onTap: () {
                                      widget.onClose();
                                      item.onTap();
                                    },
                                    onCloseAll: widget.onClose,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bridge to parent for submenus (to prevent accidental closing)
                  if (widget.isSubmenu)
                    Positioned(
                      left: -12,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        color: Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextMenuItemWidget extends StatefulWidget {
  final ContextMenuItem item;
  final VoidCallback onTap;
  final VoidCallback onCloseAll;

  const _ContextMenuItemWidget({
    required this.item,
    required this.onTap,
    required this.onCloseAll,
  });

  @override
  State<_ContextMenuItemWidget> createState() => _ContextMenuItemWidgetState();
}

class _ContextMenuItemWidgetState extends State<_ContextMenuItemWidget> {
  bool _isHovered = false;
  OverlayEntry? _submenuOverlay;
  Timer? _submenuTimer;

  void _showSubmenu() {
    _submenuTimer?.cancel();
    if (widget.item.subItems == null || _submenuOverlay != null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    // Parent item center relative to submenu top (which is shifted by -8)
    // We increase the offset significantly to move the notch down as it appears too high
    final notchY = (renderBox.size.height / 2) + 30;

    _submenuOverlay = OverlayEntry(
      builder: (context) => _ContextMenuWidget(
        position: Offset(
          position.dx + renderBox.size.width + 8,
          position.dy - 8,
        ),
        items: widget.item.subItems!,
        onClose: widget.onCloseAll,
        isSubmenu: true,
        notchY: notchY,
        onEnter: () {
          _submenuTimer?.cancel();
        },
      ),
    );

    Overlay.of(context).insert(_submenuOverlay!);
  }

  void _hideSubmenu({bool immediate = false}) {
    if (immediate) {
      _submenuOverlay?.remove();
      _submenuOverlay = null;
      _submenuTimer?.cancel();
    } else {
      _submenuTimer?.cancel();
      _submenuTimer = Timer(const Duration(milliseconds: 200), () {
        _submenuOverlay?.remove();
        _submenuOverlay = null;
      });
    }
  }

  @override
  void dispose() {
    _submenuOverlay?.remove();
    _submenuTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.isDivider) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: Colors.white10, height: 1),
      );
    }

    final isEnabled = widget.item.isEnabled;
    final isSelected = widget.item.isSelected;

    final color = widget.item.isDestructive
        ? Colors.redAccent.withOpacity(isEnabled ? 1.0 : 0.4)
        : isSelected
        ? AppColors.violet
        : Colors.white.withOpacity(isEnabled ? 1.0 : 0.4);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (isEnabled) _showSubmenu();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hideSubmenu();
      },
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: (isSelected)
                ? AppColors.violet.withOpacity(0.15)
                : (_isHovered && isEnabled)
                ? Colors.white.withOpacity(0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              if (widget.item.icon != null || isSelected) ...[
                if (isSelected && widget.item.icon == null)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.violet,
                  )
                else if (widget.item.icon != null)
                  Icon(
                    widget.item.icon,
                    size: 18,
                    color: color.withOpacity(isEnabled ? 0.8 : 0.3),
                  ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  widget.item.title,
                  style: GoogleFonts.manrope(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.item.subItems != null) ...[
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: color.withOpacity(0.4),
                ),
              ] else if (widget.item.shortcut != null) ...[
                const SizedBox(width: 12),
                Text(
                  widget.item.shortcut!,
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(isEnabled ? 0.38 : 0.15),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
