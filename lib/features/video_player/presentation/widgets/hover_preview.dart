import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hover thumbnail preview for the video progress bar.
///
/// Uses `ffmpeg` subprocess for frame extraction — completely process-isolated,
/// zero GPU contention with the main player.
///
/// Accepts a [ValueNotifier] for hover position so the parent widget
/// does NOT need to call setState during mouse hover.
/// NO BackdropFilter — uses a simple dark container to avoid GPU competition.
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
  Timer? _seekThrottle;
  bool _isDisposed = false;
  bool _isSeeking = false;
  bool _hasPendingSeek = false;
  Process? _activeProcess;

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
      _isSeeking = false;
      _hasPendingSeek = false;
      _killActiveProcess();
    }
  }

  void _onHoverChanged() {
    if (!widget.isVisible || widget.hoverXNotifier.value == null) return;

    // Throttle position rebuilds to ~33fps (30ms)
    if (_positionThrottle?.isActive != true) {
      _positionThrottle = Timer(const Duration(milliseconds: 30), () {
        if (mounted && !_isDisposed) setState(() {});
      });
    }

    // Request frame extraction (separate throttle)
    _requestSeek();
  }

  /// Leading-edge throttle for frame extraction.
  void _requestSeek() {
    if (_isSeeking) {
      _hasPendingSeek = true;
      return;
    }

    if (_seekThrottle?.isActive ?? false) {
      _hasPendingSeek = true;
      return;
    }

    // Fire immediately (leading edge)
    _extractFrame();

    // Throttle window
    _seekThrottle = Timer(const Duration(milliseconds: 250), () {
      if (_hasPendingSeek && mounted && !_isDisposed && !_isSeeking) {
        _hasPendingSeek = false;
        _extractFrame();
      }
    });
  }

  Future<void> _extractFrame() async {
    if (_isDisposed || !mounted) return;
    if (_isSeeking) return;
    if (widget.totalDuration <= Duration.zero || widget.sliderWidth <= 0) {
      return;
    }

    final hoverX = widget.hoverXNotifier.value;
    if (hoverX == null) return;

    _isSeeking = true;
    _hasPendingSeek = false;

    final fraction = (hoverX / widget.sliderWidth).clamp(0.0, 1.0);
    final targetMs =
        (fraction * widget.totalDuration.inMilliseconds).toInt();
    final seconds = targetMs / 1000.0;

    try {
      _killActiveProcess();

      _activeProcess = await Process.start(
        'ffmpeg',
        [
          '-ss', seconds.toStringAsFixed(3),
          '-i', widget.mediaPath,
          '-vframes', '1',
          '-vf', 'scale=240:-1',
          '-q:v', '5',
          '-f', 'image2pipe',
          '-vcodec', 'mjpeg',
          '-loglevel', 'error',
          '-y',
          'pipe:1',
        ],
      );

      final chunks = <List<int>>[];
      await for (final chunk in _activeProcess!.stdout) {
        chunks.add(chunk);
      }

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (_isDisposed || !mounted) return;

      if (exitCode == 0 && chunks.isNotEmpty) {
        final totalLength =
            chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
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
      _isSeeking = false;

      if (_hasPendingSeek && mounted && !_isDisposed) {
        _hasPendingSeek = false;
        _seekThrottle?.cancel();
        _seekThrottle = Timer(const Duration(milliseconds: 100), () {
          if (mounted && !_isDisposed) _extractFrame();
        });
      }
    }
  }

  void _killActiveProcess() {
    try {
      _activeProcess?.kill();
    } catch (_) {}
    _activeProcess = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionThrottle?.cancel();
    _seekThrottle?.cancel();
    _killActiveProcess();
    widget.hoverXNotifier.removeListener(_onHoverChanged);
    super.dispose();
  }

  String _formatTimestamp(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final mn = twoDigits(duration.inMinutes.remainder(60));
    final sc = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$mn:$sc';
    }
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

    final maxLeft =
        (widget.sliderWidth - _thumbWidth).clamp(0.0, double.infinity);
    final left = (hoverX - _thumbWidth / 2).clamp(0.0, maxLeft);

    // Horizontal positioning via Transform — vertical handled by parent
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
                borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(7.5),
                      child: Image.memory(
                        _thumbnailBytes!,
                        width: _thumbWidth,
                        height: _thumbHeight,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  : Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xD0101010),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatTimestamp(hoverTimestamp),
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 11,
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
