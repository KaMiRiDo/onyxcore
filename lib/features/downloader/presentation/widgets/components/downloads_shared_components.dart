import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FallbackThumb extends StatelessWidget {
  const FallbackThumb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 104,
      color: Colors.black26,
      child: const Icon(Icons.broken_image, color: Colors.white24, size: 24),
    );
  }
}

class CountIndicator extends StatelessWidget {

  const CountIndicator({
    required this.icon, required this.count, super.key,
    this.disabled = false,
  });
  final IconData icon;
  final int count;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: disabled
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: disabled ? Colors.white38 : Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.manrope(
              color: disabled ? Colors.white38 : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class CopyUrlButton extends StatefulWidget {

  const CopyUrlButton({required this.url, super.key});
  final String url;

  @override
  State<CopyUrlButton> createState() => _CopyUrlButtonState();
}

class _CopyUrlButtonState extends State<CopyUrlButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    if (widget.url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.url));
    setState(() {
      _copied = true;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _copy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'URL',
            style: GoogleFonts.manrope(
              color: _copied ? Colors.green : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
              key: ValueKey<bool>(_copied),
              color: _copied ? Colors.green : Colors.white54,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}
