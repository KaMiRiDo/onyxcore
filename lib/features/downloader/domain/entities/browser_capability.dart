/// Capabilities of a browser for the custom extractor pipeline.
enum BrowserCapability {
  /// Chromium-based browser (supported).
  chromium,
  /// Firefox-based browser (unsupported).
  firefox,
  /// Safari or other (unsupported).
  other,
  /// No browser specified.
  none,
}
