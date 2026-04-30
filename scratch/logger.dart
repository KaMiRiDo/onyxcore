import 'dart:io';

void log(String message) {
  final file = File('/home/vimal-babu/0_DRIVE/CodingWorkouts/antigravity_workouts/onyxcore/scratch/device_log.txt');
  file.writeAsStringSync('$message\n', mode: FileMode.append);
}
