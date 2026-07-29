import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  group('classifyFileType', () {
    test('classifies image files correctly', () {
      expect(classifyFileType('image.jpg'), FileItemType.image);
      expect(classifyFileType('image.PNG'), FileItemType.image);
      expect(classifyFileType('image.heic'), FileItemType.image);
      expect(classifyFileType('image.psd'), FileItemType.image);
    });

    test('classifies video files correctly', () {
      expect(classifyFileType('movie.mp4'), FileItemType.video);
      expect(classifyFileType('clip.MKV'), FileItemType.video);
      expect(classifyFileType('video.webm'), FileItemType.video);
    });

    test('classifies audio files correctly', () {
      expect(classifyFileType('song.mp3'), FileItemType.audio);
      expect(classifyFileType('track.wav'), FileItemType.audio);
      expect(classifyFileType('voice.opus'), FileItemType.audio);
    });

    test('classifies document files correctly', () {
      expect(classifyFileType('doc.pdf'), FileItemType.document);
      expect(classifyFileType('notes.md'), FileItemType.document);
      expect(classifyFileType('readme'), FileItemType.document);
      expect(classifyFileType('README.txt'), FileItemType.document);
      expect(classifyFileType('data.json'), FileItemType.document);
    });

    test('classifies archive files correctly', () {
      expect(classifyFileType('archive.zip'), FileItemType.archive);
      expect(classifyFileType('backup.tar.gz'), FileItemType.archive);
      expect(classifyFileType('image.dmg'), FileItemType.archive);
    });

    test('classifies other/unknown files correctly', () {
      expect(classifyFileType('unknown.xyz'), FileItemType.other);
      expect(classifyFileType('no_extension'), FileItemType.other);
    });
  });

  group('FileTypeClassifier.getExtensionsForType', () {
    test('returns correct extensions for given types', () {
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.image),
        kImageExtensions,
      );
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.video),
        kVideoExtensions,
      );
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.audio),
        kAudioExtensions,
      );
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.document),
        kDocumentExtensions,
      );
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.archive),
        kArchiveExtensions,
      );
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.other),
        isEmpty,
      );
      expect(
        FileTypeClassifier.getExtensionsForType(FileItemType.folder),
        isEmpty,
      );
    });
  });
}
