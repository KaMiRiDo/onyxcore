import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';

const Map<String, String> kNetworkImageHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
};

class ImageCanvas extends StatefulWidget {
  const ImageCanvas({
    required this.imagePath,
    required this.heroTag,
    required this.isConverting,
    this.isHighFrequencyInteractionActive = false,
    this.onImageSizeResolved,
    super.key,
  });

  final String imagePath;
  final String heroTag;
  final bool isConverting;
  final bool isHighFrequencyInteractionActive;
  final ValueChanged<Size>? onImageSizeResolved;

  @override
  State<ImageCanvas> createState() => _ImageCanvasState();
}

class _ImageCanvasState extends State<ImageCanvas> {
  Timer? _timer;
  bool _showHighRes = false;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _startHighResTimer();
    _resolveImageSize();
  }

  void _resolveImageSize() {
    if (widget.onImageSizeResolved == null) return;
    final isSvg = widget.imagePath.toLowerCase().endsWith('.svg');
    if (isSvg) return;

    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }

    final isNetwork =
        widget.imagePath.startsWith('http://') ||
        widget.imagePath.startsWith('https://');
    final baseProvider = isNetwork
        ? NetworkImage(widget.imagePath, headers: kNetworkImageHeaders)
        : FileImage(File(widget.imagePath)) as ImageProvider;

    _imageStream = baseProvider.resolve(ImageConfiguration.empty);
    _imageStreamListener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onImageSizeResolved?.call(
              Size(
                imageInfo.image.width.toDouble(),
                imageInfo.image.height.toDouble(),
              ),
            );
          }
        });
      },
      onError: (_, __) {},
    );
    _imageStream?.addListener(_imageStreamListener!);
  }

  @override
  void didUpdateWidget(ImageCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    final pathChanged = oldWidget.imagePath != widget.imagePath;
    final interactionChanged =
        oldWidget.isHighFrequencyInteractionActive !=
        widget.isHighFrequencyInteractionActive;

    if (pathChanged) {
      _timer?.cancel();
      _resolveImageSize();
      if (_showHighRes) {
        setState(() {
          _showHighRes = false;
        });
      } else {
        _showHighRes = false;
      }

      if (!widget.isHighFrequencyInteractionActive) {
        _startHighResTimer();
      }
    } else if (interactionChanged) {
      if (widget.isHighFrequencyInteractionActive) {
        _timer?.cancel();
        if (_showHighRes) {
          setState(() {
            _showHighRes = false;
          });
        }
      } else {
        if (!_showHighRes) {
          _startHighResTimer();
        }
      }
    }
  }

  void _startHighResTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted &&
          !widget.isHighFrequencyInteractionActive &&
          !_showHighRes) {
        setState(() {
          _showHighRes = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(tag: widget.heroTag, child: _buildImageWidget(context)),
    );
  }

  Widget _buildImageWidget(BuildContext context) {
    if (widget.isConverting) {
      return const Center(child: BubbleLoader(size: 60));
    }

    final isNetwork =
        widget.imagePath.startsWith('http://') ||
        widget.imagePath.startsWith('https://');
    final isSvg = widget.imagePath.toLowerCase().endsWith('.svg');

    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_rounded,
              size: 56,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (isSvg) {
      if (isNetwork) {
        return SvgPicture.network(
          widget.imagePath,
          placeholderBuilder: (_) => const Center(child: BubbleLoader(size: 60)),
          errorBuilder: (context, error, stackTrace) =>
              errorBuilder(context, error, stackTrace),
        );
      } else {
        return SvgPicture.file(
          File(widget.imagePath),
          placeholderBuilder: (_) => const Center(child: BubbleLoader(size: 60)),
          errorBuilder: (context, error, stackTrace) =>
              errorBuilder(context, error, stackTrace),
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
      return const Center(child: BubbleLoader(size: 60));
    }

    final baseProvider = isNetwork
        ? NetworkImage(widget.imagePath, headers: kNetworkImageHeaders)
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
      errorBuilder: errorBuilder,
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
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );

    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.center,
      children: [lowResImage, highResImage],
    );
  }
}

