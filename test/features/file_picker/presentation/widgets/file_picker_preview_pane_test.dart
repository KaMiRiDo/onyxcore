import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/file_picker_preview_pane.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('file_picker_preview_pane_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  testWidgets('renders empty state correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilePickerPreviewPane(selectedPaths: []),
        ),
      ),
    );

    expect(find.text('Select files to preview'), findsOneWidget);
    expect(find.byIcon(Icons.remove_red_eye_rounded), findsOneWidget);
  });

  testWidgets('renders multiple files with appropriate metadata', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000); // make it tall enough
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilePickerPreviewPane(
            selectedPaths: [
              '/fake/path/image.jpg',
              '/fake/path/document.pdf',
              '/fake/path/video.mp4',
              '/fake/path/audio.mp3',
              '/fake/path/unknown.bin',
            ],
          ),
        ),
      ),
    );

    expect(find.text('PREVIEW (5)'), findsOneWidget);

    expect(find.text('image.jpg'), findsOneWidget);
    expect(find.text('document.pdf'), findsOneWidget);
    expect(find.text('video.mp4'), findsOneWidget);
    expect(find.text('audio.mp3'), findsOneWidget);
    expect(find.text('unknown.bin'), findsOneWidget);

    expect(find.text('Size unknown'), findsNWidgets(5));
    
    // Check specific icons for the placeholders
    expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    expect(find.byIcon(Icons.movie_rounded), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
  });

  testWidgets('renders file size correctly based on size ranges', (tester) async {
    final file1 = File('${tempDir.path}/small.txt')..writeAsBytesSync(List.filled(500, 0)); // 500 B
    final file2 = File('${tempDir.path}/medium.txt')..writeAsBytesSync(List.filled(2048, 0)); // 2.0 KB
    final file3 = File('${tempDir.path}/large.txt')..writeAsBytesSync(List.filled(1572864, 0)); // 1.5 MB

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilePickerPreviewPane(
            selectedPaths: [file1.path, file2.path, file3.path],
          ),
        ),
      ),
    );

    expect(find.text('500 B'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('1.5 MB'), findsOneWidget);
  });

  testWidgets('updates scroll controller when paths are added', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilePickerPreviewPane(
            selectedPaths: ['/fake/path/1.txt'],
          ),
        ),
      ),
    );

    expect(find.text('PREVIEW (1)'), findsOneWidget);

    // Update with more paths
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilePickerPreviewPane(
            selectedPaths: [
              '/fake/path/1.txt',
              '/fake/path/2.txt',
              '/fake/path/3.txt',
              '/fake/path/4.txt',
              '/fake/path/5.txt',
              '/fake/path/6.txt',
              '/fake/path/7.txt',
              '/fake/path/8.txt',
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('PREVIEW (8)'), findsOneWidget);
  });
}
