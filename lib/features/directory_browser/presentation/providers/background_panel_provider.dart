// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

enum BackgroundPanelView { tasks, history, historyDetail }

/// Whether the background panel is open.
final backgroundPanelOpenProvider = StateProvider<bool>((ref) => false);

/// Which view is currently shown in the background panel.
final backgroundPanelViewProvider = StateProvider<BackgroundPanelView>(
  (ref) => BackgroundPanelView.tasks,
);

/// The ID of the history entry being viewed in detail.
final selectedHistoryIdProvider = StateProvider<String?>((ref) => null);

final backgroundPanelWidthFractionProvider = StateProvider<double>(
  (ref) => 0.25,
);
final isBackgroundPanelDraggingProvider = StateProvider<bool>((ref) => false);
