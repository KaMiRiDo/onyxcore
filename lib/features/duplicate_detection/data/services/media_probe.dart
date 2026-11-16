import 'dart:io';

/// Thin wrapper around the `ffprobe` CLI binary.
///
/// Injectable via constructor so tests can substitute a fake implementation
/// without spawning real processes.
class MediaProbe {
  const MediaProbe({this.timeout = const Duration(seconds: 15)});

  /// Timeout applied to external CLI processes to prevent indefinite hangs.
  final Duration timeout;

  /// Runs `ffprobe` with the given [args] and returns the [ProcessResult].
  Future<ProcessResult> runFfprobe(List<String> args) =>
      Process.run('ffprobe', args).timeout(timeout);

  /// Runs `ffmpeg` with the given [args] and returns the [ProcessResult].
  Future<ProcessResult> runFfmpeg(
    List<String> args, {
    bool binaryOutput = true,
  }) => Process.run(
    'ffmpeg',
    args,
    stdoutEncoding: binaryOutput ? null : systemEncoding,
  ).timeout(timeout);
}
