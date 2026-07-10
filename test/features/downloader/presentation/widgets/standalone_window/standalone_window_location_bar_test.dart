import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_location_bar.dart';

void main() {
  testWidgets('StandaloneWindowLocationBar renders correctly', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool downloadAllTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowLocationBar(
            isTrashView: false,
            isCustom: false,
            isChanged: false,
            currentPath: '/home/user/Downloads',
            totalVideos: 10,
            totalImages: 5,
            totalSize: 1048576, // 1MB
            onChangeLocation: () {},
            onExport: () {},
            onDownloadAll: () => downloadAllTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Location : '), findsOneWidget);
    expect(find.text('/home/user/Downloads'), findsOneWidget);
    expect(find.text('10 Videos • 5 Images • 1.0 MB'), findsOneWidget);
    
    expect(find.text('Download All'), findsOneWidget);
    await tester.tap(find.text('Download All'));
    expect(downloadAllTapped, isTrue);
  });
}
