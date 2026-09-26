import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_segment.dart';

class VideoEditorService {
  VideoEditorService(this.ref);

  final Ref ref;

  Future<void> trimAndMerge(
    List<VideoSegment> segments,
    String sourceFile,
  ) async {
    final notifier = ref.read(taskProvider.notifier);
    final taskId = notifier.addTask(
      title: 'Trimming Video',
      subtitle: 'Merging ${segments.length} segment(s)',
      sourcePaths: [sourceFile],
      isLight: false, // Heavy task due to FFMPEG
    );

    try {
      final parentDir = Directory(sourceFile).parent.path;
      final outputDir = Directory('$parentDir/Onyx/VideoCuts');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      final filename = sourceFile.split(Platform.pathSeparator).last;
      final basename = filename.contains('.') ? filename.substring(0, filename.lastIndexOf('.')) : filename;
      final ext = filename.contains('.') ? filename.substring(filename.lastIndexOf('.')) : '';
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFile = '${outputDir.path}/${basename}_cut_$timestamp$ext';

      // Build FFMPEG filter graph or concat list
      // For a truly lossless concat of arbitrary segments from the same file, 
      // the concat demuxer is best, but requires a text file. 
      // Alternatively, we can use the filter complex, but that requires re-encoding.
      // To keep it lossless (-c copy), we extract segments to temp files, then concat.

      final tempFiles = <String>[];
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final tempFile = '${outputDir.path}/.temp_cut_$i$ext';
        tempFiles.add(tempFile);
        
        // Extract segment
        final duration = segment.end - segment.start;
        final args = [
          '-y',
          '-ss', _formatDuration(segment.start),
          '-i', sourceFile,
          '-t', _formatDuration(duration),
          '-c', 'copy',
          tempFile,
        ];
        
        notifier.updateProgress(taskId, i / (segments.length * 2));
        notifier.updateCurrentItem(taskId, 'Extracting segment ${i+1}');
        
        final process = await Process.start('ffmpeg', args);
        process.stdout.listen((_) {});
        process.stderr.listen((_) {});
        final exitCode = await process.exitCode;
        if (exitCode != 0) throw Exception('Failed to extract segment $i');
      }

      // Concat
      notifier.updateProgress(taskId, 0.5);
      notifier.updateCurrentItem(taskId, 'Merging segments...');
      final concatListPath = '${outputDir.path}/.concat_list.txt';
      final concatList = File(concatListPath);
      final listContent = tempFiles.map((f) => "file '${f.replaceAll("'", "'\\''")}'").join('\n');
      await concatList.writeAsString(listContent);

      final concatArgs = [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', concatListPath,
        '-c', 'copy',
        outputFile,
      ];
      final process = await Process.start('ffmpeg', concatArgs);
      process.stdout.listen((_) {});
      process.stderr.listen((_) {});
      final exitCode = await process.exitCode;
      
      // Cleanup
      for (final f in tempFiles) {
        final file = File(f);
        if (await file.exists()) await file.delete();
      }
      if (await concatList.exists()) await concatList.delete();

      if (exitCode != 0) throw Exception('Failed to merge segments');
      
      notifier.updateProgress(taskId, 1.0);
      notifier.updateCurrentItem(taskId, 'Done');
      notifier.completeTask(taskId);
    } catch (e) {
      notifier.failTask(taskId, e.toString());
    }
  }

  Future<void> extractFrames(
    List<VideoSegment> segments,
    String sourceFile,
  ) async {
    final notifier = ref.read(taskProvider.notifier);
    final taskId = notifier.addTask(
      title: 'Extracting Frames',
      subtitle: '${segments.length} segment(s)',
      sourcePaths: [sourceFile],
      isLight: false,
    );

    try {
      final parentDir = Directory(sourceFile).parent.path;
      final outputDir = Directory('$parentDir/Onyx/Frames');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final duration = segment.end - segment.start;
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final outputPattern = '${outputDir.path}/frame_seg${i}_${timestamp}_%05d.png';
        
        final args = [
          '-y',
          '-ss', _formatDuration(segment.start),
          '-i', sourceFile,
          '-t', _formatDuration(duration),
          '-q:v', '2', // High quality for PNG/JPEG
          outputPattern,
        ];
        
        notifier.updateProgress(taskId, i / segments.length);
        notifier.updateCurrentItem(taskId, 'Extracting segment ${i+1}');
        
        final process = await Process.start('ffmpeg', args);
        process.stdout.listen((_) {});
        process.stderr.listen((_) {});
        final exitCode = await process.exitCode;
        if (exitCode != 0) throw Exception('Failed to extract frames for segment $i');
      }
      
      notifier.updateProgress(taskId, 1.0);
      notifier.updateCurrentItem(taskId, 'Done');
      notifier.completeTask(taskId);
    } catch (e) {
      notifier.failTask(taskId, e.toString());
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String threeDigitMillis =
        duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds.$threeDigitMillis';
  }
}

final videoEditorServiceProvider = Provider<VideoEditorService>((ref) {
  return VideoEditorService(ref);
});
