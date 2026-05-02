import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/file_item.dart';

enum FileOperationType { copy, cut, none }

class ClipboardState {
  final FileOperationType type;
  final List<String> paths;

  bool get isCut => type == FileOperationType.cut;
  bool get isCopy => type == FileOperationType.copy;

  const ClipboardState({
    this.type = FileOperationType.none,
    this.paths = const [],
  });

  ClipboardState copyWith({
    FileOperationType? type,
    List<String>? paths,
  }) {
    return ClipboardState(
      type: type ?? this.type,
      paths: paths ?? this.paths,
    );
  }
}

class ClipboardNotifier extends Notifier<ClipboardState> {
  @override
  ClipboardState build() => const ClipboardState();

  void copy(List<String> paths) {
    state = state.copyWith(
      type: FileOperationType.copy,
      paths: paths,
    );
  }

  void cut(List<String> paths) {
    state = state.copyWith(
      type: FileOperationType.cut,
      paths: paths,
    );
  }

  void clear() {
    state = const ClipboardState();
  }
}

final clipboardProvider = NotifierProvider<ClipboardNotifier, ClipboardState>(() {
  return ClipboardNotifier();
});
