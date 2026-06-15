import 'dart:io';

void log(String message) {
  try {
    final file = File(
      '/home/vimal-babu/0_DRIVE/CodingWorkouts/antigravity_workouts/onyxcore/scratch/device_log.txt',
    );
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    file.writeAsStringSync(
      '${DateTime.now()}: $message\n',
      mode: FileMode.append,
    );
  } catch (e) {
    // Fail silently in production
  }
}
