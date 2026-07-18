import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';

class ConflictRequest {

  ConflictRequest({
    required this.fileName,
    required this.destinationPath,
    required this.isFolder,
    required this.completer,
  });
  final String fileName;
  final String destinationPath;
  final bool isFolder;
  final Completer<ConflictResolution> completer;
}

class ConflictNotifier extends Notifier<List<ConflictRequest>> {
  @override
  List<ConflictRequest> build() => [];

  bool _isShowingDialog = false;
  ConflictResolution? _globalResolution;

  Future<ConflictResolution> resolveConflict({
    required String fileName,
    required String destinationPath,
    required bool isFolder,
    required BuildContext context,
  }) async {
    final completer = Completer<ConflictResolution>();
    final request = ConflictRequest(
      fileName: fileName,
      destinationPath: destinationPath,
      isFolder: isFolder,
      completer: completer,
    );

    state = [...state, request];

    _processQueue(context);

    return completer.future;
  }

  Future<void> _processQueue(BuildContext context) async {
    if (_isShowingDialog || state.isEmpty) return;

    _isShowingDialog = true;
    final request = state.first;

    if (_globalResolution != null) {
      request.completer.complete(_globalResolution!);
      state = state.skip(1).toList();
      _isShowingDialog = false;
      if (state.isNotEmpty && context.mounted) {
        _processQueue(context);
      }
      return;
    }

    final result = await showDialog<ConflictResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConflictDialog(
        fileName: request.fileName,
        destinationPath: request.destinationPath,
        isFolder: request.isFolder,
      ),
    );

    // If resolution is null, default to skip.
    final finalResolution = result?.resolution ?? ConflictResolution.skip;

    if (result?.applyToAll ?? false) {
      _globalResolution = finalResolution;
    }

    request.completer.complete(finalResolution);
    state = state.skip(1).toList();
    _isShowingDialog = false;

    // Process next if any
    if (state.isNotEmpty && context.mounted) {
      _processQueue(context);
    }
  }

  void clearGlobalResolution() {
    _globalResolution = null;
  }
}

final conflictProvider =
    NotifierProvider<ConflictNotifier, List<ConflictRequest>>(() {
      return ConflictNotifier();
    });
