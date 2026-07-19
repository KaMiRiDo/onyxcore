import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/video_player/data/repositories/playback_memory_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late PlaybackMemoryRepository repository;
  late MockAppDatabase mockDb;

  setUp(() {
    mockDb = MockAppDatabase();
    repository = PlaybackMemoryRepository(mockDb);
  });

  group('PlaybackMemoryRepository', () {
    const tPath = '/path/to/video.mp4';
    const tPosition = 5000;

    test('should save position using AppDatabase', () async {
      when(() => mockDb.savePlaybackPosition(any(), any()))
          .thenAnswer((_) async {});

      await repository.savePosition(tPath, tPosition);

      verify(() => mockDb.savePlaybackPosition(tPath, tPosition)).called(1);
    });

    test('should get position from AppDatabase', () async {
      when(() => mockDb.getPlaybackPosition(any()))
          .thenAnswer((_) async => tPosition);

      final result = await repository.getPosition(tPath);

      expect(result, tPosition);
      verify(() => mockDb.getPlaybackPosition(tPath)).called(1);
    });

    test('should return null when getting position if not in AppDatabase', () async {
      when(() => mockDb.getPlaybackPosition(any()))
          .thenAnswer((_) async => null);

      final result = await repository.getPosition(tPath);

      expect(result, isNull);
      verify(() => mockDb.getPlaybackPosition(tPath)).called(1);
    });
  });
}
