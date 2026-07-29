import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';

void main() {
  group('getFolderIconConfig', () {
    test('returns correct config for platform folders', () {
      expect(getFolderIconConfig('android').icon, Icons.android_rounded);
      expect(getFolderIconConfig('ios').icon, Icons.apple_rounded);
      expect(getFolderIconConfig('macos').icon, Icons.desktop_mac_rounded);
      expect(getFolderIconConfig('linux').icon, Icons.terminal_rounded);
      expect(getFolderIconConfig('windows').icon, Icons.window_rounded);
      expect(getFolderIconConfig('web').icon, Icons.language_rounded);
      expect(getFolderIconConfig('www').icon, Icons.language_rounded);
    });

    test('returns correct config for project & dev folders', () {
      expect(getFolderIconConfig('lib').icon, Icons.code_rounded);
      expect(getFolderIconConfig('src').icon, Icons.code_rounded);
      expect(getFolderIconConfig('test').icon, Icons.science_rounded);
      expect(getFolderIconConfig('assets').icon, Icons.collections_bookmark_rounded);
      expect(getFolderIconConfig('build').icon, Icons.inventory_2_rounded);
      expect(getFolderIconConfig('.git').icon, Icons.account_tree_rounded);
      expect(getFolderIconConfig('.vscode').icon, Icons.settings_rounded);
    });

    test('returns correct config for common user directories', () {
      expect(getFolderIconConfig('my_drive').icon, Icons.storage_rounded);
      expect(getFolderIconConfig('desktop_folder').icon, Icons.desktop_windows_rounded);
      expect(getFolderIconConfig('documents').icon, Icons.article_rounded);
      expect(getFolderIconConfig('downloads').icon, Icons.file_download_rounded);
      expect(getFolderIconConfig('my_music').icon, Icons.library_music_rounded);
      expect(getFolderIconConfig('pictures').icon, Icons.photo_library_rounded);
      expect(getFolderIconConfig('videos').icon, Icons.movie_creation_rounded);
    });

    test('returns correct config for other system directories', () {
      expect(getFolderIconConfig('snap').icon, Icons.view_in_ar_rounded);
      expect(getFolderIconConfig('public').icon, Icons.cloud_done_rounded);
      expect(getFolderIconConfig('templates').icon, Icons.file_copy_rounded);
    });

    test('returns fallback config for unknown folders', () {
      final config = getFolderIconConfig('random_folder_name');
      expect(config.icon, Icons.folder_rounded);
      expect(config.colors.length, 2);
    });
  });

  group('getFileIconConfig', () {
    test('returns correct config for programming language files', () {
      expect(getFileIconConfig('main.dart').icon, Icons.code_rounded);
      expect(getFileIconConfig('script.py').icon, Icons.terminal_rounded);
      expect(getFileIconConfig('App.java').icon, Icons.coffee_rounded);
      expect(getFileIconConfig('index.js').icon, Icons.javascript_rounded);
      expect(getFileIconConfig('server.go').icon, Icons.bolt_rounded);
      expect(getFileIconConfig('main.rs').icon, Icons.build_circle_rounded);
      expect(getFileIconConfig('helper.cpp').icon, Icons.settings_suggest_rounded);
    });

    test('returns correct config for config and markup files', () {
      expect(getFileIconConfig('config.yaml').icon, Icons.settings_input_component_rounded);
      expect(getFileIconConfig('data.json').icon, Icons.data_object_rounded);
      expect(getFileIconConfig('index.html').icon, Icons.html_rounded);
      expect(getFileIconConfig('pubspec.lock').icon, Icons.lock_rounded);
      expect(getFileIconConfig('run.sh').icon, Icons.terminal_rounded);
    });

    test('returns correct config for media files', () {
      expect(getFileIconConfig('video.mp4').icon, Icons.movie_creation_rounded);
      expect(getFileIconConfig('photo.jpg').icon, Icons.image_rounded);
      expect(getFileIconConfig('document.pdf').icon, Icons.picture_as_pdf_rounded);
      expect(getFileIconConfig('sheet.xlsx').icon, Icons.table_chart_rounded);
      expect(getFileIconConfig('archive.zip').icon, Icons.inventory_2_rounded);
      expect(getFileIconConfig('audio.mp3').icon, Icons.music_note_rounded);
      expect(getFileIconConfig('readme.md').icon, Icons.description_rounded);
    });

    test('returns fallback config for unknown files', () {
      final config = getFileIconConfig('file.unknown');
      expect(config.icon, Icons.insert_drive_file_rounded);
    });
  });
}
