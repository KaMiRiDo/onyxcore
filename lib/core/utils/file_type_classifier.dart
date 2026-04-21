/// File type classification — pure Dart (no Flutter imports).
///
/// This file is intentionally Flutter-free so it can be used inside
/// background isolates for directory listing.
enum FileItemType { folder, image, video, document, other }

/// Image file extensions recognized by the application.
const kImageExtensions = [
  '.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.svg', '.bmp', '.tiff',
];

/// Video file extensions recognized by the application.
const kVideoExtensions = [
  '.mp4', '.mkv', '.mov', '.avi', '.webm', '.flv', '.3gp',
];

/// Audio file extensions recognized by the application.
const kAudioExtensions = [
  '.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.wma', '.opus',
];

/// Classifies a filename into a [FileItemType].
FileItemType classifyFileType(String name) {
  final extension = name.contains('.') ? '.${name.split('.').last}' : '';
  final ext = extension.toLowerCase();
  if (kImageExtensions.contains(ext)) return FileItemType.image;
  if (kVideoExtensions.contains(ext)) return FileItemType.video;
  if (ext == '.md' || name.toLowerCase().startsWith('readme')) {
    return FileItemType.document;
  }
  return FileItemType.other;
}
