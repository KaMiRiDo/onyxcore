import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlaybackSpeedControl extends StatefulWidget {
  final double currentSpeed;
  final void Function(double) onSpeedSelected;

  const PlaybackSpeedControl({
    required this.currentSpeed,
    required this.onSpeedSelected,
    super.key,
  });

  static const List<double> speeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  State<PlaybackSpeedControl> createState() => _PlaybackSpeedControlState();
}

class _PlaybackSpeedControlState extends State<PlaybackSpeedControl> {
  late double _localSpeed;

  @override
  void initState() {
    super.initState();
    _localSpeed = widget.currentSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26).withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlaybackSpeedControl.speeds.map((speed) {
              final isSelected = speed == _localSpeed;
              return InkWell(
                onTap: () {
                  setState(() => _localSpeed = speed);
                  widget.onSpeedSelected(speed);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${speed}x',
                        style: GoogleFonts.manrope(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (isSelected) ...[
                        const Spacer(),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
