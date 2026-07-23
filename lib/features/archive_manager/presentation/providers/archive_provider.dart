import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/app.dart';
import 'package:onyxcore/core/widgets/toast_helper.dart';
import 'package:onyxcore/features/archive_manager/presentation/widgets/compress_dialog.dart';
import 'package:onyxcore/features/archive_manager/presentation/widgets/password_dialog.dart';
import 'package:onyxcore/features/archive_manager/services/archive_service.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:path/path.dart' as p;

class ArchiveProviderNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Extracts an archive, prompting for a password if necessary.
  Future<void> extractArchive(
    BuildContext context,
    String archivePath,
    String currentDir,
  ) async {
    final isEncrypted = await ArchiveService.isEncrypted(archivePath);
    String? password;

    if (isEncrypted) {
      if (!context.mounted) return;
      password = await PasswordDialog.show(context);
      if (password == null) {
        // User cancelled password prompt
        return;
      }
    }

    // Default: Extract into a new folder named after the archive within current directory
    final archiveName = p.basenameWithoutExtension(archivePath);
    final outputDir = p.join(currentDir, archiveName);

    if (!Directory(outputDir).existsSync()) {
      Directory(outputDir).createSync(recursive: true);
    }

    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: 'Extracting Archive',
          subtitle: p.basename(archivePath),
          sourcePaths: [archivePath],
        );

    ToastHelper.show(
      context,
      'Extracting archive in background...',
      icon: Icons.unarchive_rounded,
    );

    try {
      await ArchiveService.extract(
        archivePath: archivePath,
        outputDir: outputDir,
        password: password,
        onProgress: (progress) {
          ref.read(taskProvider.notifier).updateProgress(taskId, progress);
        },
        onLog: (log) {
          ref.read(taskProvider.notifier).addLog(taskId, log);
        },
      );
      ref.read(taskProvider.notifier).completeTask(taskId);

      final currentNow = ref.read(currentPathProvider);
      if (currentNow == currentDir) {
        ref.read(selectionProvider.notifier).deselectAll();
        ref.read(selectionProvider.notifier).select(outputDir);
      }

      final activeContext = appNavigatorKey.currentContext;
      if (activeContext != null && activeContext.mounted) {
        ToastHelper.show(
          activeContext,
          'Extraction completed successfully!',
          icon: Icons.check_circle_rounded,
        );
      }
      ref.read(directoryItemsProvider.notifier).refresh();
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
      final activeContext = appNavigatorKey.currentContext;
      if (activeContext != null && activeContext.mounted) {
        ToastHelper.show(activeContext, 'Extraction failed: $e', isError: true);
      }
    }
  }

  /// Compresses a list of items into a new archive, prompting for format/password.
  Future<void> compressItems(
    BuildContext context,
    List<String> paths,
    String currentDir,
  ) async {
    if (paths.isEmpty) return;

    final result = await CompressDialog.show(context, paths);
    if (result == null) return; // User cancelled

    final targetArchive = p.join(
      currentDir,
      '${result.archiveName}.${result.format}',
    );

    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: 'Compressing ${paths.length} items',
          subtitle: p.basename(targetArchive),
          sourcePaths: paths,
          targetPath: targetArchive,
        );

    ref.read(selectionProvider.notifier).deselectAll();
    ToastHelper.show(
      context,
      'Compressing items in background...',
      icon: Icons.archive_rounded,
    );

    try {
      await ArchiveService.compress(
        sourcePaths: paths,
        targetArchive: targetArchive,
        password: result.password,
        onProgress: (progress) {
          ref.read(taskProvider.notifier).updateProgress(taskId, progress);
        },
        onLog: (log) {
          ref.read(taskProvider.notifier).addLog(taskId, log);
        },
      );
      ref.read(taskProvider.notifier).completeTask(taskId);

      final currentNow = ref.read(currentPathProvider);
      if (currentNow == currentDir) {
        ref.read(selectionProvider.notifier).deselectAll();
        ref.read(selectionProvider.notifier).select(targetArchive);
      }

      final activeContext = appNavigatorKey.currentContext;
      if (activeContext != null && activeContext.mounted) {
        ToastHelper.show(
          activeContext,
          'Archive created successfully!',
          icon: Icons.check_circle_rounded,
        );
      }
      ref.read(directoryItemsProvider.notifier).refresh();
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
      final activeContext = appNavigatorKey.currentContext;
      if (activeContext != null && activeContext.mounted) {
        ToastHelper.show(
          activeContext,
          'Compression failed: $e',
          isError: true,
        );
      }
    }
  }
}

final archiveProvider = NotifierProvider<ArchiveProviderNotifier, void>(
  ArchiveProviderNotifier.new,
);
