import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

enum DownloadsPanelView {
  tasks,
  history,
  historyDetail,
}

final downloadsPanelOpenProvider = StateProvider<bool>((ref) => false);
final downloadsPanelViewProvider = StateProvider<DownloadsPanelView>((ref) => DownloadsPanelView.tasks);
final selectedDownloadHistoryIdProvider = StateProvider<String?>((ref) => null);
final isDownloadInputFocusedProvider = StateProvider<bool>((ref) => false);
