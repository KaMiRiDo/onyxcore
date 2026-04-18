import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

/// Entry point for secondary video player windows.
class StandaloneVideoPlayerApp extends StatelessWidget {
  final String windowId;
  final Map<String, dynamic> arguments;

  const StandaloneVideoPlayerApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  Widget build(BuildContext context) {
    // Reconstruct the file item from arguments
    final fileMap = arguments['file'] as Map<String, dynamic>;
    final item = FileItem(
      name: fileMap['name'] as String,
      path: fileMap['path'] as String,
      sizeBytes: fileMap['sizeBytes'] as int?,
      modified: DateTime.fromMillisecondsSinceEpoch(fileMap['modified'] as int),
      type: FileItemType.video,
    );
    
    // Position handoff is handled inside the VideoPreviewWidget if we pass it,
    // or we can pass a 'startPosition' argument.
    final num? rawPosition = arguments['position'];
    final double? startPosition = rawPosition?.toDouble();

    return ProviderScope(
      child: MaterialApp(
        title: item.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: VideoPreviewWidget(
            item: item,
            initialPosition: startPosition != null ? Duration(milliseconds: startPosition.toInt()) : null,
            isStandalone: true,
          ),
        ),
      ),
    );
  }
}
