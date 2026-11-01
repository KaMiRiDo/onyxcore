// ignore_for_file: cascade_invocations
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_config_notifier.dart';

void main() {
  group('CompareConfigNotifier', () {
    late Directory tempDir;
    late Directory sourceDir;
    late Directory destDir;
    late ProviderContainer container;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('compare_config_test_');
      sourceDir = Directory('${tempDir.path}/source')..createSync();
      destDir = Directory('${tempDir.path}/dest')..createSync();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('initial state has default category all and invalid status', () {
      final state = container.read(compareConfigProvider);
      expect(state.category, ComparisonCategory.all);
      expect(state.sourceFolder, isEmpty);
      expect(state.destinationFolder, isEmpty);
      expect(state.isValid, isFalse);
    });

    test('updates source and destination folders', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setSourceFolder(sourceDir.path);
      notifier.setDestinationFolder(destDir.path);

      final state = container.read(compareConfigProvider);
      expect(state.sourceFolder, sourceDir.path);
      expect(state.destinationFolder, destDir.path);
      expect(state.isValid, isTrue);
      expect(state.errorMessage, isNull);
    });

    test('updates category selection', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setCategory(ComparisonCategory.videos);
      expect(
        container.read(compareConfigProvider).category,
        ComparisonCategory.videos,
      );

      notifier.setCategory(ComparisonCategory.audio);
      expect(
        container.read(compareConfigProvider).category,
        ComparisonCategory.audio,
      );
    });

    test('fails validation when source folder is empty', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setDestinationFolder(destDir.path);
      notifier.validate();

      final state = container.read(compareConfigProvider);
      expect(state.isValid, isFalse);
      expect(state.errorMessage, contains('Source folder'));
    });

    test('fails validation when destination folder is empty', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setSourceFolder(sourceDir.path);
      notifier.validate();

      final state = container.read(compareConfigProvider);
      expect(state.isValid, isFalse);
      expect(state.errorMessage, contains('Destination folder'));
    });

    test(
      'fails validation when source and destination folders are identical',
      () {
        final notifier = container.read(compareConfigProvider.notifier);
        notifier.setSourceFolder(sourceDir.path);
        notifier.setDestinationFolder(sourceDir.path);
        notifier.validate();

        final state = container.read(compareConfigProvider);
        expect(state.isValid, isFalse);
        expect(
          state.errorMessage,
          contains('Source and destination folders cannot be the same'),
        );
      },
    );

    test('fails validation when source folder does not exist', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setSourceFolder('${tempDir.path}/non_existent_src');
      notifier.setDestinationFolder(destDir.path);
      notifier.validate();

      final state = container.read(compareConfigProvider);
      expect(state.isValid, isFalse);
      expect(state.errorMessage, contains('Source folder does not exist'));
    });

    test('fails validation when destination folder does not exist', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setSourceFolder(sourceDir.path);
      notifier.setDestinationFolder('${tempDir.path}/non_existent_dest');
      notifier.validate();

      final state = container.read(compareConfigProvider);
      expect(state.isValid, isFalse);
      expect(state.errorMessage, contains('Destination folder does not exist'));
    });

    test('builds ComparisonRequest when configuration is valid', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setSourceFolder(sourceDir.path);
      notifier.setDestinationFolder(destDir.path);
      notifier.setCategory(ComparisonCategory.images);

      final request = notifier.buildRequest();

      expect(request, isNotNull);
      expect(request!.sourceFolder, sourceDir.path);
      expect(request.destinationFolder, destDir.path);
      expect(request.category, ComparisonCategory.images);
      expect(request.recursive, isTrue);
    });

    test('buildRequest returns null when configuration is invalid', () {
      final notifier = container.read(compareConfigProvider.notifier);
      notifier.setSourceFolder(sourceDir.path);
      // destination missing

      final request = notifier.buildRequest();
      expect(request, isNull);
    });
  });
}
