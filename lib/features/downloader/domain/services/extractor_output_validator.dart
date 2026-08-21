import 'package:onyxcore/features/downloader/domain/entities/extractor_runtime_config.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';

class ExtractorOutputValidator {
  static List<String> validateRaw(dynamic decoded, {required ExtractorRuntimeConfig config, String? logs}) {
    if (decoded is! List) {
      throw ExtractorException('Extractor result must be an array of URL strings.', logs ?? '');
    }
    return validate(decoded, config: config, logs: logs);
  }

  static List<String> validate(List<dynamic> items, {required ExtractorRuntimeConfig config, String? logs}) {
    if (items.length > config.maxResults) {
      throw ExtractorException(
        'Extractor returned ${items.length} URLs, which exceeds the maximum allowed (${config.maxResults}).',
        logs ?? '',
      );
    }

    final uniqueUrls = <String>{};

    for (final item in items) {
      if (item is! String) {
        throw ExtractorException('Extractor result must be an array of URL strings. Found non-string item.', logs ?? '');
      }

      final urlStr = item.trim();
      if (urlStr.isEmpty) {
        throw ExtractorException('Extractor returned an empty URL string.', logs ?? '');
      }

      final uri = Uri.tryParse(urlStr);
      if (uri == null || !uri.hasScheme) {
        throw ExtractorException('Extractor returned an invalid URL string: $urlStr', logs ?? '');
      }

      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        throw ExtractorException('Extractor returned an unsupported URL scheme: $scheme', logs ?? '');
      }

      if (!uri.hasAuthority) {
        throw ExtractorException('Extractor returned an invalid URL string: $urlStr', logs ?? '');
      }

      uniqueUrls.add(urlStr);
    }

    return uniqueUrls.toList();
  }
}
