import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

class ImagePreviewWidget extends StatelessWidget {
  const ImagePreviewWidget({required this.item, super.key});

  final FileItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.2),
      child: Center(
        child: Hero(
          tag: item.path,
          child: Image.file(
            File(item.path),
            fit: BoxFit.contain,
            // Use high quality for full-size preview
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
