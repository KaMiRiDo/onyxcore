import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hover thumbnail preview using ffmpeg subprocess extraction.
///
/// Uses a trailing-throttle pattern for continuous updates:
/// - First hover: extract immediately (no debounce delay).
/// - While extracting: queue the latest position.
/// - When extraction finishes: immediately start the queued one.
/// This gives instant response AND continuous updates while sliding.
class HoverPreview extends StatefulWidget {
  const HoverPreview({
    required this.mediaPath,
    required this.totalDuration,
    required this.sliderWidth,
    required this.hoverXNotifier,
    required this.isVisible,
    super.key,
  });

  final String mediaPath;
  final Duration totalDuration;
  final double sliderWidth;
  final ValueNotifier<double?> hoverXNotifier;
  final bool isVisible;

  @override
  State<HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<HoverPreview> {
  Uint8List? _thumbnailBytes;
  Timer? _positionThrottle;
  bool _isDisposed = false;
  bool _isExtracting = false;
  Process? _activeProcess;
  double? _pendingHoverX; // Queued position while extraction is in-flight

  static const _thumbWidth = 160.0;
  static const _thumbHeight = 90.0;

  @override
  void initState() {
    super.initState();
    widget.hoverXNotifier.addListener(_onHoverChanged);
  }

  @override
  void didUpdateWidget(HoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hoverXNotifier != widget.hoverXNotifier) {
      oldWidget.hoverXNotifier.removeListener(_onHoverChanged);
      widget.hoverXNotifier.addListener(_onHoverChanged);
    }
    if (oldWidget.mediaPath != widget.mediaPath) {
      _thumbnailBytes = null;
      _killActiveProcess();
    }
  }

  void _onHoverChanged() {
    if (!widget.isVisible || widget.hoverXNotifier.value == null) return;

    // Throttle UI rebuilds for smooth popup tracking
    if (_positionThrottle?.isActive != true) {
      _positionThrottle = Timer(const Duration(milliseconds: 30), () {
        if (mounted && !_isDisposed) setState(() {});
      });
    }

    final hoverX = widget.hoverXNotifier.value;
    if (hoverX == null) return;

    if (_isExtracting) {
      // An extraction is already running — just queue the latest position.
      // When the current one finishes, it will pick this up immediately.
      _pendingHoverX = hoverX;
    } else {
      // No extraction running — start one immediately (zero delay)
      _extractFrame(hoverX);
    }
  }

  Future<void> _extractFrame(double hoverX) async {
    if (_isDisposed || !mounted) return;
    if (widget.totalDuration <= Duration.zero || widget.sliderWidth <= 0)
      return;

    _isExtracting = true;
    _pendingHoverX = null;

    final fraction = (hoverX / widget.sliderWidth).clamp(0.0, 1.0);
    final targetMs = (fraction * widget.totalDuration.inMilliseconds).toInt();
    final seconds = targetMs / 1000.0;

    try {
      _killActiveProcess();

      final process = await Process.start('ffmpeg', [
        '-threads',
        '2',
        '-ss',
        seconds.toStringAsFixed(3),
        '-i',
        widget.mediaPath,
        '-vframes',
        '1',
        '-an',
        '-vf',
        'scale=160:-1',
        '-q:v',
        '8',
        '-f',
        'image2pipe',
        '-vcodec',
        'mjpeg',
        '-loglevel',
        'error',
        '-y',
        'pipe:1',
      ]);

      _activeProcess = process;

      final chunks = <List<int>>[];
      await for (final chunk in process.stdout) {
        chunks.add(chunk);
      }

      final exitCode = await process.exitCode;

      if (_isDisposed || !mounted) return;

      if (exitCode == 0 && chunks.isNotEmpty) {
        final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
        final bytes = Uint8List(totalLength);
        var offset = 0;
        for (final chunk in chunks) {
          bytes.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }
        if (bytes.isNotEmpty && mounted && !_isDisposed) {
          setState(() => _thumbnailBytes = bytes);
        }
      }
    } catch (e) {
      debugPrint('[HoverPreview] ffmpeg error: $e');
    } finally {
      _activeProcess = null;
      _isExtracting = false;

      // If a new position was queued while we were extracting,
      // start the next extraction immediately — no debounce delay.
      if (_pendingHoverX != null && !_isDisposed && mounted) {
        final next = _pendingHoverX!;
        _pendingHoverX = null;
        _extractFrame(next);
      }
    }
  }

  void _killActiveProcess() {
    final p = _activeProcess;
    _activeProcess = null;
    try {
      p?.kill();
    } catch (_) {}
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionThrottle?.cancel();
    _killActiveProcess();
    widget.hoverXNotifier.removeListener(_onHoverChanged);
    super.dispose();
  }

  String _formatTimestamp(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final mn = twoDigits(duration.inMinutes.remainder(60));
    final sc = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) return '${twoDigits(duration.inHours)}:$mn:$sc';
    return '$mn:$sc';
  }

  @override
  Widget build(BuildContext context) {
    final hoverX = widget.hoverXNotifier.value;
    if (!widget.isVisible ||
        hoverX == null ||
        widget.totalDuration <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final fraction = (hoverX / widget.sliderWidth).clamp(0.0, 1.0);
    final hoverTimestamp = Duration(
      milliseconds: (fraction * widget.totalDuration.inMilliseconds).toInt(),
    );
    final maxLeft = (widget.sliderWidth - _thumbWidth).clamp(
      0.0,
      double.infinity,
    );
    final left = (hoverX - _thumbWidth / 2).clamp(0.0, maxLeft);

    return Transform.translate(
      offset: Offset(left, 0),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _thumbWidth,
              height: _thumbHeight,
              decoration: BoxDecoration(
                color: const Color(0xE0181818),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _thumbnailBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11.5),
                      child: Image.memory(
                        _thumbnailBytes!,
                        width: _thumbWidth,
                        height: _thumbHeight,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white24,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xD0101010),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatTimestamp(hoverTimestamp),
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
