import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';

void main() {
  group('Stage1Metadata', () {
    const tMetadata = Stage1Metadata(
      candidatePath: '/source/photo.jpg',
      orientation: MediaOrientation.landscape,
      aspectRatioGroup: '16:9',
      extraAttributes: {'codec': 'jpeg'},
    );

    test('supports value equality via Equatable', () {
      const tMetadata2 = Stage1Metadata(
        candidatePath: '/source/photo.jpg',
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '16:9',
        extraAttributes: {'codec': 'jpeg'},
      );
      expect(tMetadata, equals(tMetadata2));
    });

    test('inequal when orientation differs', () {
      const other = Stage1Metadata(
        candidatePath: '/source/photo.jpg',
        orientation: MediaOrientation.portrait,
        extraAttributes: {'codec': 'jpeg'},
      );
      expect(tMetadata, isNot(equals(other)));
    });

    test('inequal when aspectRatioGroup differs', () {
      const other = Stage1Metadata(
        candidatePath: '/source/photo.jpg',
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '4:3',
        extraAttributes: {'codec': 'jpeg'},
      );
      expect(tMetadata, isNot(equals(other)));
    });

    test('default extraAttributes is empty when not supplied', () {
      const meta = Stage1Metadata(
        candidatePath: '/path.mp3',
        orientation: MediaOrientation.notApplicable,
      );
      expect(meta.extraAttributes, isEmpty);
    });

    test('durationSeconds can be null (images)', () {
      const meta = Stage1Metadata(
        candidatePath: '/photo.png',
        orientation: MediaOrientation.square,
      );
      expect(meta.durationSeconds, isNull);
    });

    test('durationSeconds is set for time-based media', () {
      const meta = Stage1Metadata(
        candidatePath: '/clip.mp4',
        orientation: MediaOrientation.landscape,
        durationSeconds: 120.5,
      );
      expect(meta.durationSeconds, 120.5);
    });

    test('MediaOrientation has all expected variants', () {
      expect(
        MediaOrientation.values,
        containsAll([
          MediaOrientation.landscape,
          MediaOrientation.portrait,
          MediaOrientation.square,
          MediaOrientation.notApplicable,
          MediaOrientation.unknown,
        ]),
      );
    });

    test('notApplicable orientation is used for audio', () {
      const meta = Stage1Metadata(
        candidatePath: '/track.mp3',
        orientation: MediaOrientation.notApplicable,
        durationSeconds: 210,
      );
      expect(meta.orientation, MediaOrientation.notApplicable);
    });
  });
}
