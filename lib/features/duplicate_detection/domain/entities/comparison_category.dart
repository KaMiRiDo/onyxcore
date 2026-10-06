/// User-selectable file-type categories for duplicate comparison.
///
/// Maps directly to [FileItemType] without re-declaring the underlying type
/// constants. Only the types that make sense for duplicate detection are
/// enumerated here (images, videos, audio, other, and a catch-all).
enum ComparisonCategory {
  /// Compare every supported media file in both folders.
  all,

  /// Compare image files only.
  images,

  /// Compare video files only.
  videos,

  /// Compare audio files only.
  audio,

  /// Compare files that do not match any recognised media type.
  other,
}
