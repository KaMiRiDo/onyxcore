import 'package:flutter/material.dart';

/// Service to lazy-probe and cache the intrinsic dimensions and aspect ratio
/// of media thumbnails/direct images.
class ThumbnailAspectResolver {
  static final Map<String, Size> _resolvedSizes = {};
  static final Set<String> _pendingUrls = {};
  static final ValueNotifier<int> updates = ValueNotifier<int>(0);

  /// Returns the cached size if resolved, otherwise null.
  static Size? getSize(String? url) {
    if (url == null || url.isEmpty) return null;
    return _resolvedSizes[url];
  }

  /// Returns the cached aspect ratio (width / height) if resolved, otherwise null.
  static double? getAspectRatio(String? url) {
    final size = getSize(url);
    if (size != null && size.height > 0) {
      return size.width / size.height;
    }
    return null;
  }

  /// Asynchronously probes the intrinsic dimensions of an image via [NetworkImage].
  static void probe(String? url) {
    if (url == null || url.isEmpty) return;
    if (_resolvedSizes.containsKey(url) || _pendingUrls.contains(url)) return;

    _pendingUrls.add(url);
    final provider = NetworkImage(url);
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        final width = imageInfo.image.width.toDouble();
        final height = imageInfo.image.height.toDouble();
        if (width > 0 && height > 0) {
          _resolvedSizes[url] = Size(width, height);
          updates.value++;
        }
        _pendingUrls.remove(url);
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        _pendingUrls.remove(url);
      },
    );
    stream.addListener(listener);
  }

  @visibleForTesting
  static void setSizeForTesting(String url, Size size) {
    _resolvedSizes[url] = size;
    updates.value++;
  }

  /// Resets all cached and pending thumbnail sizes.
  static void reset() {
    _resolvedSizes.clear();
    _pendingUrls.clear();
  }
}
