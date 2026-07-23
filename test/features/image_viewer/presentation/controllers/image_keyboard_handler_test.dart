import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_keyboard_handler.dart';

void main() {
  late ImageKeyboardHandler handler;
  
  var onCloseCalled = false;
  bool? onDeletePermanent;

  setUp(() {
    onCloseCalled = false;
    onDeletePermanent = null;

    handler = ImageKeyboardHandler(
      onClose: () => onCloseCalled = true,
      onDelete: ({required bool permanent}) => onDeletePermanent = permanent,
      onToggleSidebar: () {},
      onZoomIn: () {},
      onZoomOut: () {},
      onResetZoom: () {},
      onNavigateForward: ({required bool isKeyRepeat}) {},
      onNavigateBackward: ({required bool isKeyRepeat}) {},
      onNavigateHistoryForward: () {},
      onNavigateHistoryBackward: () {},
      onToggleFullscreen: () {},
      isSidebarOpen: () => false,
      isStandalone: false,
      isWindowed: false,
    );
  });

  testWidgets('Escape calls onClose when not windowed', (tester) async {
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.escape,
      logicalKey: LogicalKeyboardKey.escape,
      timeStamp: Duration.zero,
    );
    
    final result = handler.handleKeyEvent(event);
    expect(result, KeyEventResult.handled);
    expect(onCloseCalled, true);
  });

  testWidgets('Delete calls onDelete', (tester) async {
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.delete,
      logicalKey: LogicalKeyboardKey.delete,
      timeStamp: Duration.zero,
    );
    
    final result = handler.handleKeyEvent(event);
    expect(result, KeyEventResult.handled);
    expect(onDeletePermanent, false);
  });

  // Additional tests could check Shift, Ctrl, Alt handling by faking HardwareKeyboard 
  // but HardwareKeyboard is hard to mock cleanly in unit tests without a full widget tree.
}
