import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/entities/extractor_runtime_config.dart';

/// The result of an extractor execution.
class ExtractorResult {
  ExtractorResult(this.urls, this.logs);

  final List<String> urls;
  final String logs;
}

class ExtractorException implements Exception {
  ExtractorException(this.message, this.logs);

  final String message;
  final String logs;

  @override
  String toString() => message;
}

/// The contract for the service that executes custom extractors.
// ignore: one_member_abstracts
abstract class ExtractorRuntimeService {
  /// Executes a custom extractor script against a target URL.
  Future<ExtractorResult> execute(
    CustomExtractor extractor,
    String url, {
    BrowserInfo? browser,
    ExtractorRuntimeConfig? config,
    void Function(String)? onLog,
    void Function(int pid)? onProcessStarted,
  });
}
