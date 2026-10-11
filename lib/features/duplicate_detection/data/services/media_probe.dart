import 'dart:io';

/// Thin wrapper around the `ffprobe` CLI binary.
///
/// Injectable via constructor so tests can substitute a fake implementation
/// without spawning real processes.
class MediaProbe {
  const MediaProbe();

  /// Runs `ffprobe` with the given [args] and returns the [ProcessResult].
  Future<ProcessResult> runFfprobe(List<String> args) =>
      Process.run('ffprobe', args);
}
