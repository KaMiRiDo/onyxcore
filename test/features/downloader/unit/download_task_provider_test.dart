import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DownloadTaskNotifier progress updates for single video download', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(downloadTaskProvider.notifier);

    notifier.startDownload(
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      destination: '/mock/destination',
      title: 'Rick Astley - Never Gonna Give You Up',
      downloadType: 'video',
      isPlaylist: false,
      isProfile: false,
      totalItems: 1,
    );

    final tasks = container.read(downloadTaskProvider);
    final taskId = tasks.first.id;

    notifier.parseProgressForTesting(taskId, '[#004b80 5.7MiB/214MiB(2%) CN:16 DL:6.6MiB ETA:31s]');

    final updatedTasks = container.read(downloadTaskProvider);
    final task = updatedTasks.first;

    expect(task.progress, 0.02);
    expect(task.totalSize, '5.7MiB / 214MiB');
    expect(task.speed, '6.6MiB');
    expect(task.eta, '31s');
  });

  test('DownloadTaskNotifier ignores standard progress when isPlaylist is true and expectedBytes > 0', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(downloadTaskProvider.notifier);

    // Start a playlist download task with expectedBytes > 0
    notifier.startDownload(
      url: 'https://www.youtube.com/playlist?list=PL-bgVzzRdaPhE4h7u9OWe0cf7P6H-MpeM',
      destination: '/mock/destination',
      title: 'AWS With Java Course',
      downloadType: 'playlist',
      isPlaylist: true,
      isProfile: false,
      totalItems: 25,
      expectedBytes: 214000000,
    );

    final tasks = container.read(downloadTaskProvider);
    final taskId = tasks.first.id;

    // Simulate stdout progress update
    notifier.parseProgressForTesting(taskId, '[#004b80 5.7MiB/214MiB(2%) CN:16 DL:6.6MiB ETA:31s]');

    final updatedTasks = container.read(downloadTaskProvider);
    final task = updatedTasks.first;

    print('--- PLAYLIST TEST RESULT ---');
    print('task.progress: ${task.progress}');
    print('task.totalSize: ${task.totalSize}');
    print('task.speed: ${task.speed}');
    print('task.eta: ${task.eta}');
    print('-------------------');

    // Standard progress calculates 0.0008 based on 2% of first item out of 25 total
    expect(task.progress, 0.0008);
    expect(task.totalSize, '5.7MiB / 214MiB');
    // But speed and eta should still be updated (since they are not ignored)
    expect(task.speed, '6.6MiB');
    expect(task.eta, '31s');
  });
}
