import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';

abstract class CustomExtractorRepository {
  /// Watch all custom extractors.
  Stream<List<CustomExtractor>> watchAll();

  /// Get all custom extractors.
  Future<List<CustomExtractor>> getAll();

  /// Save or update a custom extractor.
  Future<void> save(CustomExtractor extractor);

  /// Delete a custom extractor by ID.
  Future<void> delete(String id);
}
