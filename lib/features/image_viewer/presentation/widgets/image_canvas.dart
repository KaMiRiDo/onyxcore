import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';

class ImageCanvas extends StatefulWidget {
  const ImageCanvas({
    required this.imagePath,
    required this.heroTag,
    required this.isConverting,
    this.isHighFrequencyInteractionActive = false,
    super.key,
  });

  final String imagePath;
  final String heroTag;
  final bool isConverting;
  final bool isHighFrequencyInteractionActive;

  @override
  State<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends State<ImageCanvas> {
  Timer? _timer;
  bool _showHighRes = false;

  @override
  void initState() {
    super.initState();
    _startHighResTimer();
  }

  @override
  void didUpdateWidget(ImageCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _showHighRes = false;
      _startHighResTimer();
    }
  }

  void _startHighResTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showHighRes = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: widget.heroTag,
        child: _buildImageWidget(context),
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context) {
    if (widget.isConverting) {
      return const Center(
        child: BubbleLoader(size: 60),
      );
    }

    final isNetwork =
        widget.imagePath.startsWith('http://') || widget.imagePath.startsWith('https://');
    final isSvg = widget.imagePath.toLowerCase().endsWith('.svg');

    if (isSvg) {
      if (isNetwork) {
        return SvgPicture.network(
          widget.imagePath,
          placeholderBuilder: (_) => const Center(
            child: BubbleLoader(size: 60),
          ),
        );
      } else {
        return SvgPicture.file(
          File(widget.imagePath),
          placeholderBuilder: (_) => const Center(
            child: BubbleLoader(size: 60),
          ),
        );
      }
    }

    final filterQuality = widget.isHighFrequencyInteractionActive
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

    final baseProvider = isNetwork
        ? NetworkImage(widget.imagePath)
        : FileImage(File(widget.imagePath)) as ImageProvider;

    final lowResImage = Image(
      image: ResizeImage(
        baseProvider,
        width: 1920,
        height: 1920,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.contain,
      filterQuality: filterQuality,
      frameBuilder: frameBuilder,
    );

    if (!_showHighRes) {
      return lowResImage;
    }

    final highResImage = Image(
      image: baseProvider,
      fit: BoxFit.contain,
      filterQuality: filterQuality,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );

    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: [
        lowResImage,
        highResImage,
      ],
    );
  }
}
