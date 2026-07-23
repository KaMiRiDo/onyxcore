import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';

class ImageCanvas extends StatelessWidget {
  const ImageCanvas({
    required this.imagePath,
    required this.heroTag,
    required this.isConverting,
    this.rotationAngle = 0.0,
    this.brightness = 0.0,
    this.isHighFrequencyInteractionActive = false,
    super.key,
  });

  final String imagePath;
  final String heroTag;
  final bool isConverting;
  final double rotationAngle;
  final double brightness;
  final bool isHighFrequencyInteractionActive;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: heroTag,
        child: Transform.rotate(
          angle: rotationAngle * 3.14159 / 180,
          child: brightness != 0.0
              ? ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    1, 0, 0, 0, brightness * 255,
                    0, 1, 0, 0, brightness * 255,
                    0, 0, 1, 0, brightness * 255,
                    0, 0, 0, 1, 0,
                  ]),
                  child: _buildImageWidget(),
                )
              : _buildImageWidget(),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (isConverting) {
      return const Center(
        child: BubbleLoader(size: 60),
      );
    }

    final isNetwork =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');
    final isSvg = imagePath.toLowerCase().endsWith('.svg');

    if (isSvg) {
      if (isNetwork) {
        return SvgPicture.network(
          imagePath,
          placeholderBuilder: (_) => const Center(
            child: BubbleLoader(size: 60),
          ),
        );
      } else {
        return SvgPicture.file(
          File(imagePath),
          placeholderBuilder: (_) => const Center(
            child: BubbleLoader(size: 60),
          ),
        );
      }
    }

    final filterQuality = isHighFrequencyInteractionActive
        ? FilterQuality.low
        : FilterQuality.high;

    Widget frameBuilder(
      BuildContext context,
      Widget child,
      int? frame,
      // ignore: avoid_positional_boolean_parameters
      bool wasSynchronouslyLoaded,
    ) {
      if (wasSynchronouslyLoaded || frame != null) return child;
      return const Center(
        child: BubbleLoader(size: 60),
      );
    }

    if (isNetwork) {
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        cacheWidth: 3840,
        filterQuality: filterQuality,
        frameBuilder: frameBuilder,
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.contain,
        cacheWidth: 3840,
        filterQuality: filterQuality,
        frameBuilder: frameBuilder,
      );
    }
  }
}
