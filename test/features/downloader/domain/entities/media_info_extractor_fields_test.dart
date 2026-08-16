import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

void main() {
  group('MediaInfo Extractor Fields', () {
    test('has isExtractorGroup, extractorId, extractorName', () {
      final info = MediaInfo(
        id: '1',
        title: 'Test',
        originalUrl: 'http://test.com',
        isExtractorGroup: true,
        extractorId: 'ext-1',
        extractorName: 'My Extractor',
      );
      
      expect(info.isExtractorGroup, true);
      expect(info.extractorId, 'ext-1');
      expect(info.extractorName, 'My Extractor');
    });

    test('copyWith supports new fields', () {
      final info = MediaInfo(
        id: '1',
        title: 'Test',
        originalUrl: 'http://test.com',
      );
      
      final modified = info.copyWith(
        isExtractorGroup: true,
        extractorId: 'ext-1',
        extractorName: 'My Extractor',
      );
      
      expect(modified.isExtractorGroup, true);
      expect(modified.extractorId, 'ext-1');
      expect(modified.extractorName, 'My Extractor');
    });

    test('toMap and fromMap retain extractor fields', () {
      final info = MediaInfo(
        id: '1',
        title: 'Test',
        originalUrl: 'http://test.com',
        isExtractorGroup: true,
        extractorId: 'ext-1',
        extractorName: 'My Extractor',
      );
      
      final map = info.toMap();
      final decoded = MediaInfo.fromMap(map);
      
      expect(decoded.isExtractorGroup, true);
      expect(decoded.extractorId, 'ext-1');
      expect(decoded.extractorName, 'My Extractor');
    });
  });
}
