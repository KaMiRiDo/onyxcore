# Audio Metadata Utils Test Document

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-AUD-META-01 | audio_metadata_utils.dart | readTags | return a Tag object for a valid audio file | Provide a valid file path to an audio file with embedded ID3 tags | Call AudioMetadataUtils.readTags(path) | Returns non-null Tag with expected title, artist, album fields |
| U-AUD-META-02 | audio_metadata_utils.dart | readTags | return null for a file with no tags | Provide a valid file path to an audio file without ID3 tags | Call AudioMetadataUtils.readTags(path) | Returns null |
| U-AUD-META-03 | audio_metadata_utils.dart | readTags | return null when file does not exist | Provide a non-existent file path | Call AudioMetadataUtils.readTags(path) | Returns null (catches exception) |
| U-AUD-META-04 | audio_metadata_utils.dart | readTags | return null when path is a directory | Provide a directory path | Call AudioMetadataUtils.readTags(path) | Returns null (catches exception) |
| U-AUD-META-05 | audio_metadata_utils.dart | writeTags | return true on successful tag write | Provide valid path and Tag object | Call AudioMetadataUtils.writeTags(path, tag) | Returns true |
| U-AUD-META-06 | audio_metadata_utils.dart | writeTags | return false when file does not exist | Provide non-existent file path | Call AudioMetadataUtils.writeTags(path, tag) | Returns false (catches exception) |
| U-AUD-META-07 | audio_metadata_utils.dart | writeTags | return false when write permission denied | Provide a read-only file path | Call AudioMetadataUtils.writeTags(path, tag) | Returns false (catches exception) |
| U-AUD-META-08 | audio_metadata_utils.dart | prepareCoverArt | return correctly sized JPEG for a valid image | Provide Uint8List of a 1200x800 PNG image | Call AudioMetadataUtils.prepareCoverArt(bytes) | Returns Uint8List of 600x600 JPEG |
| U-AUD-META-09 | audio_metadata_utils.dart | prepareCoverArt | crop landscape image to square before resizing | Provide Uint8List of a 1200x600 landscape image | Call AudioMetadataUtils.prepareCoverArt(bytes) | Returns a square 600x600 image (center-cropped from original) |
| U-AUD-META-10 | audio_metadata_utils.dart | prepareCoverArt | crop portrait image to square before resizing | Provide Uint8List of a 600x1200 portrait image | Call AudioMetadataUtils.prepareCoverArt(bytes) | Returns a square 600x600 image (center-cropped from original) |
| U-AUD-META-11 | audio_metadata_utils.dart | prepareCoverArt | respect custom targetSize parameter | Provide Uint8List of a 1200x1200 image | Call AudioMetadataUtils.prepareCoverArt(bytes, targetSize: 300) | Returns a 300x300 JPEG |
| U-AUD-META-12 | audio_metadata_utils.dart | prepareCoverArt | return null for invalid/corrupt image bytes | Provide Uint8List of random non-image bytes | Call AudioMetadataUtils.prepareCoverArt(bytes) | Returns null |
| U-AUD-META-13 | audio_metadata_utils.dart | prepareCoverArt | return null for empty byte array | Provide empty Uint8List | Call AudioMetadataUtils.prepareCoverArt(bytes) | Returns null |
| U-AUD-META-14 | audio_metadata_utils.dart | prepareCoverArt | produce JPEG output at 90% quality | Provide valid image bytes | Call prepareCoverArt and decode result | Result bytes decode as a valid JPEG image |
| U-AUD-META-15 | audio_metadata_utils.dart | prepareCoverArt | handle already-square images without cropping artifacts | Provide Uint8List of a 500x500 image | Call AudioMetadataUtils.prepareCoverArt(bytes) | Returns 600x600 image (upscaled cleanly) |
| U-AUD-META-16 | audio_metadata_utils.dart | getProperties | return populated AudioProperties for a valid audio file | Mock Process.run to return valid ffprobe JSON output | Call AudioMetadataUtils.getProperties(path) | Returns AudioProperties with correct duration, bitrate, sampleRate |
| U-AUD-META-17 | audio_metadata_utils.dart | getProperties | return "Unknown" fields when ffprobe is not available | Mock Process.run to throw exception | Call AudioMetadataUtils.getProperties(path) | Returns AudioProperties(duration: 'Unknown', bitrate: 'Unknown', sampleRate: 'Unknown') |
| U-AUD-META-18 | audio_metadata_utils.dart | getProperties | return "Unknown" fields when ffprobe returns non-zero exit code | Mock Process.run to return exitCode 1 | Call AudioMetadataUtils.getProperties(path) | Returns AudioProperties with all "Unknown" |
| U-AUD-META-19 | audio_metadata_utils.dart | getProperties | return "Unknown" fields when ffprobe returns empty stdout | Mock Process.run to return exitCode 0 with empty stdout | Call AudioMetadataUtils.getProperties(path) | Returns AudioProperties with all "Unknown" |
| U-AUD-META-20 | audio_metadata_utils.dart | getProperties | parse bitrate from format field preferring format over stream | Mock ffprobe JSON with format.bit_rate="320000" and stream.bit_rate="128000" | Call getProperties | Returns bitrate "320 kbps" |
| U-AUD-META-21 | audio_metadata_utils.dart | getProperties | fallback to stream bitrate when format bitrate is missing | Mock ffprobe JSON with only stream.bit_rate="256000" | Call getProperties | Returns bitrate "256 kbps" |
| U-AUD-META-22 | audio_metadata_utils.dart | getProperties | return "Unknown" bitrate when value is 0 or absent | Mock ffprobe JSON with bit_rate=0 | Call getProperties | Returns bitrate "Unknown" |
| U-AUD-META-23 | audio_metadata_utils.dart | getProperties | format sample rate with Hz suffix | Mock ffprobe JSON with sample_rate="44100" | Call getProperties | Returns sampleRate "44100 Hz" |
| U-AUD-META-24 | audio_metadata_utils.dart | _formatDuration | format duration under 1 hour as MM:SS | Internal: seconds=125.5 | Call _formatDuration(125.5) | Returns "02:05" |
| U-AUD-META-25 | audio_metadata_utils.dart | _formatDuration | format duration over 1 hour as H:MM:SS | Internal: seconds=3661.0 | Call _formatDuration(3661.0) | Returns "1:01:01" |
| U-AUD-META-26 | audio_metadata_utils.dart | _formatDuration | return "Unknown" for 0 or negative seconds | Internal: seconds=0 | Call _formatDuration(0) | Returns "Unknown" |
| U-AUD-META-27 | audio_metadata_utils.dart | _formatDuration | return "Unknown" for negative seconds | Internal: seconds=-5.0 | Call _formatDuration(-5.0) | Returns "Unknown" |
| U-AUD-META-28 | audio_metadata_utils.dart | getProperties | handle malformed JSON gracefully | Mock Process.run to return exitCode 0 with invalid JSON | Call getProperties | Returns AudioProperties with all "Unknown" |
| U-AUD-META-29 | audio_metadata_utils.dart | AudioProperties | store all three fields correctly | Construct AudioProperties | Read fields | duration, bitrate, sampleRate are correct |

### 2. Widget Test Plan Format
N/A - Pure Domain Logic
