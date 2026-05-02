import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/conflict_dialog.dart';

class ConflictRequest {
  final String fileName;
  final String destinationPath;
  final bool isFolder;
  final Completer<ConflictResolution> completer;

  ConflictRequest({
    required this.fileName,
    required this.destinationPath,
    required this.isFolder,
    required this.completer,
  });
}

class ConflictNotifier extends Notifier<List<ConflictRequest>> {
  @override
  List<ConflictRequest> build() => [];

  bool _isShowingDialog = false;

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

  void _processQueue(BuildContext context) async {
    if (_isShowingDialog || state.isEmpty) return;

    _isShowingDialog = true;
    final request = state.first;

    final resolution = await showDialog<ConflictResolution>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConflictDialog(
        fileName: request.fileName,
        destinationPath: request.destinationPath,
        isFolder: request.isFolder,
      ),
    );

    // If resolution is null (shouldn't happen with our new dialog but as fallback),
    // default to skip.
    final finalResolution = resolution ?? ConflictResolution.skip;
    
    request.completer.complete(finalResolution);
    
    state = state.skip(1).toList();
    _isShowingDialog = false;
    
    // Process next if any
    if (state.isNotEmpty && context.mounted) {
      _processQueue(context);
    }
  }
}

final conflictProvider = NotifierProvider<ConflictNotifier, List<ConflictRequest>>(() {
  return ConflictNotifier();
});
