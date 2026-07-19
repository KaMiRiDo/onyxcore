import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';

void main() {
  group('VideoMarker', () {
    const tMarker = VideoMarker(
      id: 'test_id',
      timestamp: Duration(milliseconds: 1000),
      content: 'test_content',
    );

    test('should return correct props', () {
      expect(tMarker.props, [
        'test_id',
        const Duration(milliseconds: 1000),
        'test_content',
        '📍',
      ]);
    });

    test('should convert to json correctly', () {
      final json = tMarker.toJson();
      expect(json, {
        'id': 'test_id',
        'timestamp': 1000,
        'content': 'test_content',
        'icon': '📍',
      });
    });

    test('should create from json correctly', () {
      final json = {
        'id': 'test_id',
        'timestamp': 1000,
        'content': 'test_content',
        'icon': '📍',
      };
      final marker = VideoMarker.fromJson(json);
      expect(marker, equals(tMarker));
    });

    test('should create from json with missing icon correctly', () {
      final json = {
        'id': 'test_id',
        'timestamp': 1000,
        'content': 'test_content',
      };
      final marker = VideoMarker.fromJson(json);
      expect(marker, equals(tMarker));
    });

    test('copyWith should return a new object with updated values', () {
      final updated = tMarker.copyWith(
        id: 'new_id',
        timestamp: const Duration(milliseconds: 2000),
        content: 'new_content',
        icon: '📌',
      );
      
      expect(updated.id, 'new_id');
      expect(updated.timestamp, const Duration(milliseconds: 2000));
      expect(updated.content, 'new_content');
      expect(updated.icon, '📌');
    });

    test('copyWith should return a new object with same values if none provided', () {
      final updated = tMarker.copyWith();
      expect(updated, equals(tMarker));
    });
  });
}
