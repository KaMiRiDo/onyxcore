import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_viewer_lifecycle.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';

void main() {
  testWidgets('ImageViewerLifecycle initializes and completes firstFrame', (tester) async {
    final focusNode = FocusNode();
    final zoomAnimationController = AnimationController(vsync: const TestVSync());
    var onReadyForInteractionCalled = false;
    var onFirstFrameCalled = false;

    final lifecycle = ImageViewerLifecycle(
      windowId: null,
      isStandalone: false,
      focusNode: focusNode,
      zoomAnimationController: zoomAnimationController,
      onWindowFocus: () {},
      onReadyForInteraction: () => onReadyForInteractionCalled = true,
      onFirstFrame: () => onFirstFrameCalled = true,
    );

    final ref = ProviderContainer();
    final item = FileItem(
      path: '/test/image.jpg',
      name: 'image.jpg',
      type: FileItemType.image,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: ref,
      child: Consumer(
        builder: (context, widgetRef, _) {
          lifecycle.initialize(
            context: context,
            ref: widgetRef,
            item: item,
            isMounted: true,
          );
          return const SizedBox();
        },
      ),
    ));

    // Pump to trigger post-frame callbacks
    await tester.pump();
    
    expect(lifecycle.firstFrame, completes);
    expect(ref.read(imageIsEmptyProvider), false);
    expect(ref.read(imageRootPathProvider), '/test');
    expect(ref.read(imageCurrentPathProvider), '/test');
    expect(onFirstFrameCalled, true);

    // Wait for the 350ms delay
    await tester.pump(const Duration(milliseconds: 350));
    expect(onReadyForInteractionCalled, true);
  });
}
