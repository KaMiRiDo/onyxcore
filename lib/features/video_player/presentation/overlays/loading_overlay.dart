import 'package:flutter/material.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';

/// Unified loading overlay shown during open, initial seek, smart buffering,
/// and seek-loader states.
///
/// Mirrors the `AnimatedOpacity + BubbleLoader` block originally at
/// lines 2650–2671 of `video_preview_widget.dart`.
class VideoLoadingOverlay extends StatelessWidget {
  const VideoLoadingOverlay({required this.isVisible, super.key});

  /// Whether the loader should be fully opaque.
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isVisible ? 1.0 : 0.0,
          child: const RepaintBoundary(child: BubbleLoader(size: 100)),
        ),
      ),
    );
  }
}
