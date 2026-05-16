// ignore: unused_import, Required for FileSystem type used in setupMockFileSystem signature.
import 'package:file/file.dart';
import 'package:file/memory.dart';

/// Creates and returns a [MemoryFileSystem] pre-populated with a
/// realistic Linux user directory tree.
///
/// This helper is designed to be called in `setUp()` blocks across
/// all test suites, providing a consistent, sandboxed filesystem
/// for every test run.
///
/// Structure created:
/// ```text
/// /home/user/
/// ├── Desktop/
/// ├── Documents/
/// │   ├── report.txt
/// │   └── notes.txt
/// ├── Downloads/
/// │   ├── photo.png
/// │   └── installer.deb
/// ├── Music/
/// ├── Pictures/
/// │   └── wallpaper.jpg
/// ├── Videos/
/// │   └── clip.mp4
/// └── .hidden_file
/// ```
MemoryFileSystem setupMockFileSystem() {
  final fs = MemoryFileSystem();

  // ── Root user directories ──
  fs.directory('/home/user/Desktop').createSync(recursive: true);
  fs.directory('/home/user/Documents').createSync(recursive: true);
  fs.directory('/home/user/Downloads').createSync(recursive: true);
  fs.directory('/home/user/Music').createSync(recursive: true);
  fs.directory('/home/user/Pictures').createSync(recursive: true);
  fs.directory('/home/user/Videos').createSync(recursive: true);

  // ── Documents ──
  fs.file('/home/user/Documents/report.txt')
    ..createSync(recursive: true)
    ..writeAsStringSync('Sample report content');

  fs.file('/home/user/Documents/notes.txt')
    ..createSync(recursive: true)
    ..writeAsStringSync('Sample notes');

  // ── Downloads ──
  fs.file('/home/user/Downloads/photo.png')
    ..createSync(recursive: true)
    ..writeAsStringSync('PNG_MOCK_DATA');

  fs.file('/home/user/Downloads/installer.deb')
    ..createSync(recursive: true)
    ..writeAsStringSync('DEB_MOCK_DATA');

  // ── Pictures ──
  fs.file('/home/user/Pictures/wallpaper.jpg')
    ..createSync(recursive: true)
    ..writeAsStringSync('JPG_MOCK_DATA');

  // ── Videos ──
  fs.file('/home/user/Videos/clip.mp4')
    ..createSync(recursive: true)
    ..writeAsStringSync('MP4_MOCK_DATA');

  // ── Hidden file ──
  fs.file('/home/user/.hidden_file')
    ..createSync(recursive: true)
    ..writeAsStringSync('hidden');

  return fs;
}
