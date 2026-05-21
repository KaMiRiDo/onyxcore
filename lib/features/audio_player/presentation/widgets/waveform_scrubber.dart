import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:media_kit/media_kit.dart';
import '../providers/audio_player_providers.dart';

class WaveformScrubber extends ConsumerStatefulWidget {
  final String fileName;

  const WaveformScrubber({required this.fileName, super.key});

  @override
  ConsumerState<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends ConsumerState<WaveformScrubber> {
  /// The playback position captured at the moment the user starts dragging.
  Duration? _scrubAnchor;

  /// The cumulative horizontal drag distance (in pixels) since drag start.
  double _scrubDragAccumulator = 0.0;

  /// Virtual position shown during scrubbing (for smooth UI feedback).
  Duration? _virtualScrubPosition;

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);
    final player = ref.watch(audioPlayerProvider);

    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? Duration.zero;

    // During scrubbing, use the virtual position for UI so it doesn't snap back.
    final displayPosition = _virtualScrubPosition ?? position;

    final progress = duration.inMilliseconds > 0 
        ? displayPosition.inMilliseconds / duration.inMilliseconds 
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const barWidth = 3.0;
        const gap = 2.0;
        final barCount = (width / (barWidth + gap)).floor();

        return Column(
          children: [
            GestureDetector(
              onHorizontalDragStart: (details) => _onDragStart(position, duration, player),
              onHorizontalDragUpdate: (details) => _onDragUpdate(details, width, duration, player),
              onHorizontalDragEnd: (_) => _onDragEnd(),
              onHorizontalDragCancel: () => _onDragEnd(),
              onTapDown: (details) => _handleTapSeek(details.localPosition.dx, width, duration, player),
              child: SizedBox(
                height: 60,
                width: width,
                child: CustomPaint(
                  painter: WaveformPainter(
                    progress: progress,
                    barCount: barCount,
                    seed: widget.fileName.hashCode,
                    barWidth: barWidth,
                    gap: gap,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(displayPosition),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  "-${_formatDuration(duration - displayPosition)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Called when the user starts a horizontal drag (scrub).
  /// Captures the current playback position as the anchor.
  void _onDragStart(Duration currentPosition, Duration duration, Player? player) {
    if (duration.inMilliseconds <= 0 || player == null) return;
    setState(() {
      _scrubAnchor = currentPosition;
      _scrubDragAccumulator = 0.0;
      _virtualScrubPosition = currentPosition;
    });
  }

  /// Called on each drag update. Computes the new seek position relative
  /// to the anchor (where playback was when the drag started).
  void _onDragUpdate(DragUpdateDetails details, double totalWidth, Duration totalDuration, Player? player) {
    if (totalDuration.inMilliseconds <= 0 || player == null || _scrubAnchor == null) return;

    _scrubDragAccumulator += details.delta.dx;

    // Convert accumulated pixel drag to a duration offset.
    // Full waveform width = full duration, so each pixel = duration / width.
    final msPerPixel = totalDuration.inMilliseconds / totalWidth;
    final offsetMs = (_scrubDragAccumulator * msPerPixel).toInt();
    final newMs = (_scrubAnchor!.inMilliseconds + offsetMs)
        .clamp(0, totalDuration.inMilliseconds);
    final seekTo = Duration(milliseconds: newMs);

    setState(() {
      _virtualScrubPosition = seekTo;
    });
    player.seek(seekTo);
  }

  /// Called when the drag ends. Clears scrub state.
  void _onDragEnd() {
    setState(() {
      _scrubAnchor = null;
      _scrubDragAccumulator = 0.0;
      _virtualScrubPosition = null;
    });
  }

  /// Tap seeks to the absolute position on the waveform (existing behavior).
  void _handleTapSeek(double x, double totalWidth, Duration totalDuration, Player? player) {
    if (totalDuration.inMilliseconds <= 0 || player == null) return;
    final percentage = (x / totalWidth).clamp(0.0, 1.0);
    final seekTo = Duration(milliseconds: (totalDuration.inMilliseconds * percentage).toInt());
    player.seek(seekTo);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final int barCount;
  final int seed;
  final double barWidth;
  final double gap;

  WaveformPainter({
    required this.progress,
    required this.barCount,
    required this.seed,
    required this.barWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final playedPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [AppColors.magenta, AppColors.violet],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final unplayedPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final playheadPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final barHeight = 10 + random.nextDouble() * (size.height - 10);
      final x = i * (barWidth + gap);
      final isPlayed = (x / size.width) <= progress;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          (size.height - barHeight) / 2,
          barWidth,
          barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, isPlayed ? playedPaint : unplayedPaint);

      // Playhead indicator
      if ((x / size.width - progress).abs() < (barWidth + gap) / size.width / 2) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x,
              0,
              barWidth,
              size.height,
            ),
            const Radius.circular(2),
          ),
          playheadPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.barCount != barCount;
  }
}
