import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:media_kit/media_kit.dart';
import '../providers/audio_player_providers.dart';

class WaveformScrubber extends ConsumerWidget {
  final String fileName;

  const WaveformScrubber({required this.fileName, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);
    final player = ref.watch(audioPlayerProvider);

    final position = positionAsync.value ?? Duration.zero;
    final duration = durationAsync.value ?? Duration.zero;

    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
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
              onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition.dx, width, duration, player),
              onTapDown: (details) => _handleSeek(details.localPosition.dx, width, duration, player),
              child: SizedBox(
                height: 60,
                width: width,
                child: CustomPaint(
                  painter: WaveformPainter(
                    progress: progress,
                    barCount: barCount,
                    seed: fileName.hashCode,
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
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  "-${_formatDuration(duration - position)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _handleSeek(double x, double totalWidth, Duration totalDuration, Player? player) {
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
