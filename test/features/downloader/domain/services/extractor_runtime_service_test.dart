import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';

class MockExtractorRuntimeService extends Mock implements ExtractorRuntimeService {}
class FakeCustomExtractor extends Fake implements CustomExtractor {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCustomExtractor());
  });

  group('ExtractorRuntimeService tests', () {
    test('Mock runtime service returns items', () async {
      final mockService = MockExtractorRuntimeService();
      final extractor = CustomExtractor(
        id: '1',
        name: 'test',
        script: 'console.log("test");',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      // Define behavior
      when(() => mockService.execute(any(), any(), browser: any(named: 'browser'), onLog: any(named: 'onLog'))).thenAnswer((_) async => ExtractorResult([
        'http://media.com/1.mp4',
      ], 'test log'));
      
      final results = await mockService.execute(extractor, 'http://test.com');
      expect(results.urls.length, 1);
      expect(results.urls.first, 'http://media.com/1.mp4');
      expect(results.logs, 'test log');
    });
  });
}
