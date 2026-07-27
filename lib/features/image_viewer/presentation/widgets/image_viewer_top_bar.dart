import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';

class ImageViewerTopBar extends ConsumerWidget {
  const ImageViewerTopBar({
    required this.title,
    required this.isStandalone,
    required this.isEmpty,
    required this.isNetworkStream,
    required this.itemPath,
    this.metadata,
    this.onPopOut,
    this.onClose,
    super.key,
  });

  final String title;
  final String? metadata;
  final bool isStandalone;
  final bool isEmpty;
  final bool isNetworkStream;
  final String itemPath;
  final VoidCallback? onPopOut;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ViewerTopBar(
      title: title,
      metadata: metadata,
      isStandalone: isStandalone,
      onPopOut: onPopOut,
      onClose: onClose,
      extraActions: [
        if (!isEmpty) ...[
          if (!isNetworkStream)
            Consumer(
              builder: (context, ref, _) {
                final favorites = ref.watch(imageFavoritesProvider);
                final isFavorite = favorites.contains(itemPath);
                return _buildTopBarButton(
                  icon: isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  onPressed: () {
                    ref.read(imageFavoritesProvider.notifier).toggleFavorite(itemPath);
                  },
                  tooltip: 'Toggle Favorite',
                  active: isFavorite,
                );
              },
            ),
          if (!isNetworkStream) const SizedBox(width: 8),
          if (!isNetworkStream)
            _buildTopBarButton(
              icon: Icons.edit_outlined,
              onPressed: null, // intentional no-op to disable but keep visible
              tooltip: 'Edit Image',
            ),
          if (!isNetworkStream) const SizedBox(width: 8),
          _buildTopBarButton(
            icon: Icons.settings_rounded,
            onPressed: () => SettingsDialog.show(
              context,
              initialTab: 1,
              section: 'Image',
            ),
            tooltip: 'Image Settings',
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildTopBarButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool active = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: active
            ? Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5))
            : null,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: active ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: onPressed == null ? 0.3 : 1.0),
          size: 20,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }
}
