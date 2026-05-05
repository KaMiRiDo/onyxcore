import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ViewerTopBar extends StatelessWidget {
  final String title;
  final String? metadata;
  final VoidCallback? onPopOut;
  final VoidCallback? onClose;
  final bool isStandalone;
  final List<Widget>? extraActions;

  const ViewerTopBar({
    required this.title,
    this.metadata,
    this.onPopOut,
    this.onClose,
    this.isStandalone = false,
    this.extraActions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (metadata != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata!,
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Actions Area
            if (extraActions != null) ...extraActions!,
            if (!isStandalone) ...[
              const SizedBox(width: 8),
              if (onPopOut != null) ...[
                _buildButton(
                  icon: Icons.open_in_new_rounded,
                  onPressed: onPopOut!,
                  tooltip: 'Pop Out',
                ),
                const SizedBox(width: 8),
              ],
              if (onClose != null)
                _buildButton(
                  icon: Icons.close_rounded,
                  onPressed: onClose!,
                  tooltip: 'Close',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }
}
