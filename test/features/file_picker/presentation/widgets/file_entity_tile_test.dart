import 'package:file/file.dart' as file_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/file_entity_tile.dart';

import '../../../../helpers/file_system_helper.dart';

void main() {
  late file_pkg.FileSystem fs;

  setUp(() {
    fs = setupMockFileSystem();
  });

  Widget buildTile(
    file_pkg.FileSystemEntity entity, {
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FileEntityTile(
          entity: entity,
          isSelected: isSelected,
          onTap: onTap ?? () {},
          onDoubleTap: onDoubleTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders folder entity correctly', (tester) async {
    final folder = fs.directory('/home/user/Documents');
    await tester.pumpWidget(buildTile(folder));
    
    expect(find.text('Documents'), findsOneWidget);
    expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
  });

  testWidgets('renders file entities with appropriate icons', (tester) async {
    // Text file
    final txtFile = fs.file('/home/user/Documents/report.txt');
    await tester.pumpWidget(buildTile(txtFile));
    expect(find.text('report.txt'), findsOneWidget);
    expect(find.byIcon(Icons.description_rounded), findsOneWidget);

    // Image file
    final imgFile = fs.file('/home/user/Pictures/wallpaper.jpg');
    await tester.pumpWidget(buildTile(imgFile));
    expect(find.text('wallpaper.jpg'), findsOneWidget);
    expect(find.byIcon(Icons.image_rounded), findsOneWidget);

    // Video file
    final videoFile = fs.file('/home/user/Videos/clip.mp4');
    await tester.pumpWidget(buildTile(videoFile));
    expect(find.text('clip.mp4'), findsOneWidget);
    expect(find.byIcon(Icons.video_collection_rounded), findsOneWidget);
  });


}
