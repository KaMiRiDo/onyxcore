import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_config_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_selection_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_runner_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_progress_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_results_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_setup_view.dart';

/// Top-level view hosted within the dedicated secondary compare window.
class CompareWindow extends ConsumerStatefulWidget {
  const CompareWindow({
    required this.windowId,
    required this.initialParams,
    super.key,
  });

  final int windowId;
  final WindowParams initialParams;

  @override
  ConsumerState<CompareWindow> createState() => _CompareWindowState();
}

class _CompareWindowState extends ConsumerState<CompareWindow> {
  late final ComparisonRunnerNotifier _runnerNotifier;
  late final CompareConfigNotifier _configNotifier;
  late final CompareSelectionNotifier _selectionNotifier;

  @override
  void initState() {
    super.initState();
    _runnerNotifier = ref.read(comparisonRunnerProvider.notifier);
    _configNotifier = ref.read(compareConfigProvider.notifier);
    _selectionNotifier = ref.read(compareSelectionProvider.notifier);
    PersistentViewerManager.getFocusTrigger(widget.windowId)
        .addListener(_onWindowFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyInitialParams();
    });
  }

  void _onWindowFocus() {
    if (mounted) {
      _verifyExistingFiles();
      setState(() {});
    }
  }

  void _verifyExistingFiles() {
    final result = ref.read(comparisonRunnerProvider).result;
    if (result == null || result.isEmpty) return;
    final missing = <String>{};
    for (final match in result.matches) {
      if (!File(match.sourcePath).existsSync() &&
          !Directory(match.sourcePath).existsSync()) {
        missing.add(match.sourcePath);
      }
      for (final dest in match.destinationMatches) {
        if (!File(dest.destinationPath).existsSync() &&
            !Directory(dest.destinationPath).existsSync()) {
          missing.add(dest.destinationPath);
        }
      }
    }
    if (missing.isNotEmpty) {
      _runnerNotifier.removePaths(missing);
      _selectionNotifier.removePaths(missing);
    }
  }

  @override
  void didUpdateWidget(CompareWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.windowId != oldWidget.windowId) {
      PersistentViewerManager.getFocusTrigger(oldWidget.windowId)
          .removeListener(_onWindowFocus);
      PersistentViewerManager.getFocusTrigger(widget.windowId)
          .addListener(_onWindowFocus);
    }
    if (widget.initialParams != oldWidget.initialParams) {
      _applyInitialParams();
    }
  }

  @override
  void dispose() {
    PersistentViewerManager.getFocusTrigger(widget.windowId)
        .removeListener(_onWindowFocus);
    Future.microtask(() {
      _runnerNotifier.reset();
      _configNotifier.reset();
      _selectionNotifier.reset();
    });
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  void _applyInitialParams() {
    _runnerNotifier.reset();
    _configNotifier.reset();
    _selectionNotifier.reset();

    final init = widget.initialParams.initParams;
    final source =
        init['sourceFolder'] as String? ?? widget.initialParams.file.path;
    final dest = init['destinationFolder'] as String?;
    final catName = init['category'] as String?;

    if (source.isNotEmpty) {
      _configNotifier.setSourceFolder(source);
    }
    if (dest != null && dest.isNotEmpty) {
      _configNotifier.setDestinationFolder(dest);
    }
    if (catName != null) {
      final category = ComparisonCategory.values.firstWhere(
        (c) => c.name == catName,
        orElse: () => ComparisonCategory.all,
      );
      _configNotifier.setCategory(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runnerState = ref.watch(comparisonRunnerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.compare_arrows_rounded,
              color: AppColors.violet,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Folder Comparison',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildBody(runnerState),
        ),
      ),
    );
  }

  Widget _buildBody(ComparisonRunnerState state) {
    if (state.isProcessing && state.progress != null) {
      return CompareProgressView(
        progress: state.progress!,
        onCancel: () => ref.read(comparisonRunnerProvider.notifier).cancel(),
      );
    }

    if (state.progress?.status == ComparisonStatus.cancelled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cancel_outlined,
                color: Colors.amberAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Comparison Cancelled',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The comparison was cancelled before completion.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () =>
                    ref.read(comparisonRunnerProvider.notifier).reset(),
                child: Text(
                  'Reconfigure',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Comparison Failed',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () =>
                    ref.read(comparisonRunnerProvider.notifier).reset(),
                child: Text(
                  'Reconfigure',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.result != null) {
      final config = ref.watch(compareConfigProvider);
      return CompareResultsView(
        result: state.result!,
        sourceFolder: config.sourceFolder,
        destinationFolder: config.destinationFolder,
        onNewComparison: () =>
            ref.read(comparisonRunnerProvider.notifier).reset(),
      );
    }

    return CompareSetupView(
      onStart: () {
        final request = ref.read(compareConfigProvider.notifier).buildRequest();
        if (request != null) {
          ref.read(comparisonRunnerProvider.notifier).startComparison(request);
        }
      },
    );
  }
}
