import 'package:flutter/material.dart';

// Re-export the pure-Dart types used everywhere
export 'package:onyxcore/core/utils/file_type_classifier.dart';

import 'package:onyxcore/core/utils/file_type_classifier.dart';

/// Configuration for rendering a file/folder icon with gradient colors.
class FileIconConfig {
  const FileIconConfig(this.icon, this.colors);

  final IconData icon;
  final List<Color> colors;
}

/// Returns the icon configuration for a named folder.
///
/// Provides unique icons + gradient colors for well-known folder names
/// like android, ios, lib, test, assets, etc.
FileIconConfig getFolderIconConfig(String name) {
  final lowName = name.toLowerCase();

  // Platform & OS logos
  if (lowName == 'android') {
    return FileIconConfig(Icons.android_rounded, [
      const Color(0xFF1B5E20),
      const Color(0xFF3DDC84),
    ]);
  }
  if (lowName == 'ios') {
    return FileIconConfig(Icons.apple_rounded, [
      const Color(0xFF424242),
      const Color(0xFFBDBDBD),
    ]);
  }
  if (lowName == 'macos') {
    return FileIconConfig(Icons.desktop_mac_rounded, [
      const Color(0xFF0277BD),
      const Color(0xFFBBDEFB),
    ]);
  }
  if (lowName == 'linux') {
    return FileIconConfig(Icons.terminal_rounded, [
      const Color(0xFF212121),
      const Color(0xFF424242),
    ]);
  }
  if (lowName == 'windows') {
    return FileIconConfig(Icons.window_rounded, [
      const Color(0xFF01579B),
      const Color(0xFF00A4EF),
    ]);
  }
  if (lowName == 'web' || lowName == 'www') {
    return FileIconConfig(Icons.language_rounded, [
      const Color(0xFF0277BD),
      const Color(0xFF4FC3F7),
    ]);
  }

  // Project & Dev Categories
  if (lowName == 'lib' || lowName == 'src') {
    return FileIconConfig(Icons.code_rounded, [
      const Color(0xFF0D47A1),
      const Color(0xFF42A5F5),
    ]);
  }
  if (lowName == 'test' || lowName == 'tests') {
    return FileIconConfig(Icons.science_rounded, [
      const Color(0xFF1B5E20),
      const Color(0xFF66BB6A),
    ]);
  }
  if (lowName == 'assets' || lowName == 'res' || lowName == 'resource') {
    return FileIconConfig(Icons.collections_bookmark_rounded, [
      const Color(0xFFFF6F00),
      const Color(0xFFFFD54F),
    ]);
  }
  if (lowName == 'build' || lowName == 'bin' || lowName == 'dist') {
    return FileIconConfig(Icons.inventory_2_rounded, [
      const Color(0xFF455A64),
      const Color(0xFFB0BEC5),
    ]);
  }
  if (lowName == '.git') {
    return FileIconConfig(Icons.account_tree_rounded, [
      const Color(0xFFD32F2F),
      const Color(0xFFF05032),
    ]);
  }
  if (lowName == '.vscode' ||
      lowName == '.idea' ||
      lowName == 'config' ||
      lowName == 'settings') {
    return FileIconConfig(Icons.settings_rounded, [
      const Color(0xFF005A9E),
      const Color(0xFF007ACC),
    ]);
  }
  if (lowName == 'logs' || lowName == 'log') {
    return FileIconConfig(Icons.description_rounded, [
      const Color(0xFF37474F),
      const Color(0xFF78909C),
    ]);
  }

  // Standard Locations
  if (lowName.contains('drive')) {
    return FileIconConfig(Icons.storage_rounded, [
      const Color(0xFF01579B),
      const Color(0xFF00C2FF),
    ]);
  }
  if (lowName.contains('desktop')) {
    return FileIconConfig(Icons.desktop_windows_rounded, [
      const Color(0xFFE65100),
      const Color(0xFFFFD54F),
    ]);
  }
  if (lowName.contains('document')) {
    return FileIconConfig(Icons.article_rounded, [
      const Color(0xFF4527A0),
      const Color(0xFF9575CD),
    ]);
  }
  if (lowName.contains('download')) {
    return FileIconConfig(Icons.file_download_rounded, [
      const Color(0xFF01579B),
      const Color(0xFF4FC3F7),
    ]);
  }
  if (lowName.contains('music')) {
    return FileIconConfig(Icons.library_music_rounded, [
      const Color(0xFFC2185B),
      const Color(0xFFF06292),
    ]);
  }
  if (lowName.contains('picture')) {
    return FileIconConfig(Icons.photo_library_rounded, [
      const Color(0xFFE65100),
      const Color(0xFFFFB74D),
    ]);
  }
  if (lowName.contains('video')) {
    return FileIconConfig(Icons.movie_creation_rounded, [
      const Color(0xFFBF360C),
      const Color(0xFFFF7043),
    ]);
  }

  // System Folders
  if (lowName == 'snap') {
    return FileIconConfig(Icons.view_in_ar_rounded, [
      const Color(0xFFBA68C8),
      const Color(0xFF8E24AA),
    ]);
  }
  if (lowName == 'public') {
    return FileIconConfig(Icons.cloud_done_rounded, [
      const Color(0xFF4DB6AC),
      const Color(0xFF00897B),
    ]);
  }
  if (lowName == 'template' || lowName == 'templates') {
    return FileIconConfig(Icons.file_copy_rounded, [
      const Color(0xFFE65100),
      const Color(0xFFFFB74D),
    ]);
  }

  // Generic Folder (Vibrant Gold)
  return FileIconConfig(Icons.folder_rounded, [
    const Color(0xFFFFA000),
    const Color(0xFFFFD54F),
  ]);
}

/// Returns the icon configuration for a file based on its name/extension.
///
/// Maps file extensions to appropriate Material icons + gradient colors.
FileIconConfig getFileIconConfig(String name) {
  final ext = name.toLowerCase().split('.').length > 1
      ? '.${name.toLowerCase().split('.').last}'
      : '';

  // Developer & Language Files
  if (ext == '.dart') {
    return FileIconConfig(Icons.code_rounded, [
      const Color(0xFF01579B),
      const Color(0xFF00B0FF),
    ]);
  }
  if (ext == '.py') {
    return FileIconConfig(Icons.terminal_rounded, [
      const Color(0xFF3776AB),
      const Color(0xFFFFD43B),
    ]);
  }
  if (ext == '.java') {
    return FileIconConfig(Icons.coffee_rounded, [
      const Color(0xFFE76F00),
      const Color(0xFFFFAB40),
    ]);
  }
  if (ext == '.js' || ext == '.ts') {
    return FileIconConfig(Icons.javascript_rounded, [
      const Color(0xFFFFD600),
      const Color(0xFFFFEA00),
    ]);
  }
  if (ext == '.go') {
    return FileIconConfig(Icons.bolt_rounded, [
      const Color(0xFF00ADD8),
      const Color(0xFF5DC9E2),
    ]);
  }
  if (ext == '.rs') {
    return FileIconConfig(Icons.build_circle_rounded, [
      const Color(0xFFDEA584),
      const Color(0xFFE8E8E8),
    ]);
  }
  if (ext == '.cpp' || ext == '.c' || ext == '.h') {
    return FileIconConfig(Icons.settings_suggest_rounded, [
      const Color(0xFF00599C),
      const Color(0xFF004482),
    ]);
  }
  if (ext == '.yaml' || ext == '.yml') {
    return FileIconConfig(Icons.settings_input_component_rounded, [
      const Color(0xFFFF1744),
      const Color(0xFFFF5252),
    ]);
  }
  if (ext == '.json') {
    return FileIconConfig(Icons.data_object_rounded, [
      const Color(0xFFFFD600),
      const Color(0xFFFFEB3B),
    ]);
  }
  if (ext == '.xml' || ext == '.html' || ext == '.css') {
    return FileIconConfig(Icons.html_rounded, [
      const Color(0xFFFF6D00),
      const Color(0xFFFFAB40),
    ]);
  }
  if (ext == '.lock') {
    return FileIconConfig(Icons.lock_rounded, [
      const Color(0xFF607D8B),
      const Color(0xFFB0BEC5),
    ]);
  }
  if (ext == '.sh' || ext == '.bat' || ext == '.bin') {
    return FileIconConfig(Icons.terminal_rounded, [
      const Color(0xFF1B5E20),
      const Color(0xFF4CAF50),
    ]);
  }

  // Media & Docs
  if (ext == '.mp4' || ext == '.mov' || ext == '.mkv' || ext == '.webm') {
    return FileIconConfig(Icons.movie_creation_rounded, [
      const Color(0xFFD32F2F),
      const Color(0xFFFF5252),
    ]);
  }
  if (ext == '.jpg' ||
      ext == '.jpeg' ||
      ext == '.png' ||
      ext == '.webp' ||
      ext == '.heic') {
    return FileIconConfig(Icons.image_rounded, [
      const Color(0xFF2E7D32),
      const Color(0xFF69F0AE),
    ]);
  }
  if (ext == '.pdf') {
    return FileIconConfig(Icons.picture_as_pdf_rounded, [
      const Color(0xFF1565C0),
      const Color(0xFF448AFF),
    ]);
  }
  if (ext == '.xlsx' || ext == '.csv') {
    return FileIconConfig(Icons.table_chart_rounded, [
      const Color(0xFF00C853),
      const Color(0xFF69F0AE),
    ]);
  }
  if (ext == '.zip' ||
      ext == '.rar' ||
      ext == '.7z' ||
      ext == '.tar' ||
      ext == '.gz') {
    return FileIconConfig(Icons.inventory_2_rounded, [
      const Color(0xFFFF6F00),
      const Color(0xFFFFAB40),
    ]);
  }
  if (ext == '.mp3' || ext == '.wav' || ext == '.flac' || ext == '.aac') {
    return FileIconConfig(Icons.music_note_rounded, [
      const Color(0xFF7B1FA2),
      const Color(0xFFE040FB),
    ]);
  }
  if (ext == '.txt' || ext == '.md' || ext == '.log' || ext == '.env') {
    return FileIconConfig(Icons.description_rounded, [
      const Color(0xFF0277BD),
      const Color(0xFF40C4FF),
    ]);
  }

  return FileIconConfig(Icons.insert_drive_file_rounded, [
    const Color(0xFF546E7A),
    const Color(0xFF90A4AE),
  ]);
}
