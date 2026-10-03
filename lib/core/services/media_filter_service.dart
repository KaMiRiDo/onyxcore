import 'dart:io';

import 'package:path/path.dart' as p;

/// Provides the "Sort/Filter" feature: moving the currently open media file
/// into a `Filtered` subfolder inside its parent directory.
///
/// This class is intentionally stateless and side-effect-free except for the
/// [moveToFiltered] method, making it straightforward to unit-test.
abstract final class MediaFilterService {
  /// The name of the destination subfolder created inside the media's parent.
  static const String filteredFolderName = 'Filtered';

  /// Computes the destination path without performing any I/O.
  ///
  /// Given `/parent/dir/file.ext`, returns `/parent/dir/Filtered/file.ext`.
  static String resolveDestination(String sourcePath) {
    final parent = p.dirname(sourcePath);
    final name = p.basename(sourcePath);
    return p.join(parent, filteredFolderName, name);
  }

  /// Moves [sourcePath] into a `Filtered` subfolder adjacent to the source file.
  ///
  /// - Creates the `Filtered` directory if it does not already exist.
  /// - If the destination already exists, it is overwritten (mirrors the rename
  ///   API's behaviour and avoids silent duplication).
  /// - Returns the new absolute path of the moved file.
  ///
  /// Throws if the file cannot be moved (e.g. permission denied, source not
  /// found).  Callers are responsible for error handling.
  static Future<String> moveToFiltered(String sourcePath) async {
    final destination = resolveDestination(sourcePath);
    final destDir = Directory(p.dirname(destination));

    // Create the Filtered folder if needed (non-recursive: parent must exist)
    if (!destDir.existsSync()) {
      await destDir.create();
    }

    final sourceFile = File(sourcePath);
    try {
      // rename() is atomic and O(1) when source and destination share a device.
      await sourceFile.rename(destination);
    } catch (_) {
      // Cross-device rename not supported — fall back to copy + delete.
      await sourceFile.copy(destination);
      await sourceFile.delete();
    }

    return destination;
  }
}
