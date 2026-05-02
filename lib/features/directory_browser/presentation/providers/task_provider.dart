import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum FileTaskStatus { running, completed, error }

class FileTask {
  final String id;
  final String title;
  final String subtitle;
  final double progress; // 0.0 to 1.0
  final FileTaskStatus status;
  final String? errorMessage;
  final bool isCancelled;

  const FileTask({
    required this.id,
    required this.title,
    required this.subtitle,
    this.progress = 0.0,
    this.status = FileTaskStatus.running,
    this.errorMessage,
    this.isCancelled = false,
  });

  FileTask copyWith({
    String? title,
    String? subtitle,
    double? progress,
    FileTaskStatus? status,
    String? errorMessage,
    bool? isCancelled,
  }) {
    return FileTask(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

class TaskNotifier extends Notifier<List<FileTask>> {
  @override
  List<FileTask> build() => [];

  String addTask({required String title, required String subtitle}) {
    final id = const Uuid().v4();
    state = [
      ...state,
      FileTask(id: id, title: title, subtitle: subtitle),
    ];
    return id;
  }

  void updateProgress(String id, double progress) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(progress: progress);
      }
      return task;
    }).toList();
  }

  void completeTask(String id) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(status: FileTaskStatus.completed, progress: 1.0);
      }
      return task;
    }).toList();
    
    // Auto-remove completed tasks after a delay
    Future.delayed(const Duration(seconds: 3), () {
      removeTask(id);
    });
  }

  void failTask(String id, String error) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(status: FileTaskStatus.error, errorMessage: error);
      }
      return task;
    }).toList();
  }

  void cancelAllTasks() {
    state = state.map((task) {
      if (task.status == FileTaskStatus.running) {
        return task.copyWith(isCancelled: true, status: FileTaskStatus.error, errorMessage: 'Cancelled');
      }
      return task;
    }).toList();
  }

  bool isTaskCancelled(String id) {
    return state.any((t) => t.id == id && t.isCancelled);
  }

  void removeTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }
}

final taskProvider = NotifierProvider<TaskNotifier, List<FileTask>>(() {
  return TaskNotifier();
});
