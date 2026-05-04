/// File type classification — pure Dart (no Flutter imports).
///
/// This file is intentionally Flutter-free so it can be used inside
/// background isolates for directory listing.
enum FileItemType { folder, image, video, audio, document, archive, other }

/// Image file extensions recognized by the application.
const kImageExtensions = [
  '.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.svg', '.bmp', '.tiff', '.raw', '.ico', '.psd', '.ai',
];

/// Video file extensions recognized by the application.
const kVideoExtensions = [
  '.mp4', '.mkv', '.mov', '.avi', '.webm', '.flv', '.3gp', '.wmv', '.mpg', '.mpeg', '.m4v', '.ts',
];

/// Audio file extensions recognized by the application.
const kAudioExtensions = [
  '.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.wma', '.opus', '.mid', '.midi', '.aiff', '.alac',
];

/// Document file extensions.
const kDocumentExtensions = [
  '.pdf', '.docx', '.doc', '.txt', '.md', '.epub', '.pptx', '.xlsx', '.rtf', '.odt', '.csv', '.xml', '.json', '.yaml', '.log',
];

/// Archive file extensions.
const kArchiveExtensions = [
  '.zip', '.rar', '.7z', '.tar', '.gz', '.xz', '.bz2', '.iso', '.dmg', '.tgz',
];

/// Classifies a filename into a [FileItemType].
FileItemType classifyFileType(String name) {
  final extension = name.contains('.') ? '.${name.split('.').last}' : '';
  final ext = extension.toLowerCase();
  if (kImageExtensions.contains(ext)) return FileItemType.image;
  if (kVideoExtensions.contains(ext)) return FileItemType.video;
  if (kAudioExtensions.contains(ext)) return FileItemType.audio;
  if (kDocumentExtensions.contains(ext) || name.toLowerCase().startsWith('readme')) {
    return FileItemType.document;
  }
  if (kArchiveExtensions.contains(ext)) return FileItemType.archive;
  return FileItemType.other;
}

class FileTypeClassifier {
  static List<String> getExtensionsForType(FileItemType type) {
    switch (type) {
      case FileItemType.image:
        return kImageExtensions;
      case FileItemType.video:
        return kVideoExtensions;
      case FileItemType.audio:
        return kAudioExtensions;
      case FileItemType.document:
        return kDocumentExtensions;
      case FileItemType.archive:
        return kArchiveExtensions;
      default:
        return [];
    }
  }
}
