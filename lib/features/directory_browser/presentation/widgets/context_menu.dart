import 'dart:ui';
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

  const ContextMenuItem({
    required this.title,
    this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.shortcut,
    this.isDivider = false,
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

  static void show(BuildContext context, Offset position, List<ContextMenuItem> items) {
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

  const _ContextMenuWidget({
    required this.position,
    required this.items,
    required this.onClose,
  });

  @override
  State<_ContextMenuWidget> createState() => _ContextMenuWidgetState();
}

class _ContextMenuWidgetState extends State<_ContextMenuWidget> {
  @override
  Widget build(BuildContext context) {
    // Determine screen size to prevent menu from going off-screen
    final screenSize = MediaQuery.of(context).size;
    final double menuWidth = 240;
    // Estimate menu height: padding + (items * item height)
    final double menuHeight = 16 + (widget.items.length * 40);

    double left = widget.position.dx;
    double top = widget.position.dy;

    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 8;
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 8;
    }

    return Stack(
      children: [
        // Full screen transparent overlay to close on tap outside
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            onSecondaryTapDown: (_) => widget.onClose(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // The context menu itself
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: menuWidth,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.map((item) => _ContextMenuItemWidget(
                      item: item,
                      onTap: () {
                        widget.onClose();
                        item.onTap();
                      },
                    )).toList(),
                  ),
                ),
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

  const _ContextMenuItemWidget({
    required this.item,
    required this.onTap,
  });

  @override
  State<_ContextMenuItemWidget> createState() => _ContextMenuItemWidgetState();
}

class _ContextMenuItemWidgetState extends State<_ContextMenuItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.item.isDivider) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: Colors.white10, height: 1),
      );
    }

    final color = widget.item.isDestructive ? Colors.redAccent : Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 18, color: color.withOpacity(0.8)),
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
              if (widget.item.shortcut != null) ...[
                const SizedBox(width: 12),
                Text(
                  widget.item.shortcut!,
                  style: GoogleFonts.manrope(
                    color: Colors.white38,
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
