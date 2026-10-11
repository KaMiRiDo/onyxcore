import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_normalizer.dart';

void main() {
  group('Stage1Normalizer', () {
    group('normalizeOrientation', () {
      test('width > height -> landscape', () {
        expect(
          Stage1Normalizer.normalizeOrientation(1920, 1080),
          MediaOrientation.landscape,
        );
      });
      test('height > width -> portrait', () {
        expect(
          Stage1Normalizer.normalizeOrientation(1080, 1920),
          MediaOrientation.portrait,
        );
      });
      test('exactly equal -> square', () {
        expect(
          Stage1Normalizer.normalizeOrientation(1000, 1000),
          MediaOrientation.square,
        );
      });
      test('nearly equal (within 2%) -> square', () {
        expect(
          Stage1Normalizer.normalizeOrientation(1020, 1000),
          MediaOrientation.square,
        );
        expect(
          Stage1Normalizer.normalizeOrientation(1000, 1019),
          MediaOrientation.square,
        );
      });
      test('just outside 2% -> landscape/portrait', () {
        expect(
          Stage1Normalizer.normalizeOrientation(1021, 1000),
          MediaOrientation.landscape,
        );
        expect(
          Stage1Normalizer.normalizeOrientation(1000, 1021),
          MediaOrientation.portrait,
        );
      });
      test('invalid dimensions -> unknown', () {
        expect(
          Stage1Normalizer.normalizeOrientation(0, 1000),
          MediaOrientation.unknown,
        );
        expect(
          Stage1Normalizer.normalizeOrientation(1000, -5),
          MediaOrientation.unknown,
        );
      });
    });

    group('normalizeAspectRatio', () {
      test('16:9 HD vs 4K -> same group', () {
        final ar1 = Stage1Normalizer.normalizeAspectRatio(1920, 1080);
        final ar2 = Stage1Normalizer.normalizeAspectRatio(3840, 2160);
        expect(ar1, ar2);
        expect(ar1, isNotNull);
      });
      test('16:9 vs 4:3 -> different groups', () {
        final ar1 = Stage1Normalizer.normalizeAspectRatio(1920, 1080);
        final ar2 = Stage1Normalizer.normalizeAspectRatio(1600, 1200);
        expect(ar1, isNot(equals(ar2)));
      });
      test('portrait vs landscape of same ratio -> same group', () {
        final ar1 = Stage1Normalizer.normalizeAspectRatio(1920, 1080);
        final ar2 = Stage1Normalizer.normalizeAspectRatio(1080, 1920);
        expect(ar1, ar2);
      });
      test('invalid dimensions -> null', () {
        expect(Stage1Normalizer.normalizeAspectRatio(0, 1080), isNull);
      });
    });
  });
}
