import 'package:file/file.dart' as file_pkg;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/file_picker/presentation/providers/file_picker_notifier.dart';
import 'package:onyxcore/services/file_system_service.dart';

import '../../../../helpers/file_system_helper.dart';

void main() {
  late ProviderContainer container;
  late FileSystemService fileSystemService;

  setUp(() {
    final fs = setupMockFileSystem();
    fileSystemService = FileSystemService(fs);
    container = ProviderContainer(
      overrides: [
        fileSystemServiceProvider.overrideWithValue(fileSystemService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('initial state has correct default values', () {
    final state = container.read(filePickerProvider).value;
    expect(state, isNotNull);
    expect(state!.contents, isEmpty);
    expect(state.selection, isEmpty);
    expect(state.showHiddenFiles, isFalse);
    expect(state.pickDirectory, isFalse);
  });

  test('initialize loads initial directory contents (filtering hidden)', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user');

    final state = container.read(filePickerProvider).value;
    expect(state!.currentDirectory, '/home/user');
    // From mock setup: Desktop, Documents, Downloads, Music, Pictures, Videos
    expect(state.contents.length, 6); 
    expect(state.contents.any((e) => e.basename == '.hidden_file'), isFalse);
  });

  test('initialize with allowedExtensions filters non-matching files', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(
      initialDirectory: '/home/user/Documents',
      allowedExtensions: ['pdf'], // report.txt and notes.txt shouldn't match
    );

    final state = container.read(filePickerProvider).value;
    expect(state!.contents, isEmpty);
  });

  test('initialize with pickDirectory only shows directories', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(
      initialDirectory: '/home/user/Downloads',
      pickDirectory: true,
    );

    final state = container.read(filePickerProvider).value;
    expect(state!.contents.whereType<file_pkg.Directory>().length, state.contents.length);
    // Downloads has photo.png and installer.deb, so if pickDirectory is true, it should show 0 directories
    expect(state.contents, isEmpty);
  });

  test('goToDirectory updates path and loads new contents', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user');
    await notifier.goToDirectory('/home/user/Documents');

    final state = container.read(filePickerProvider).value;
    expect(state!.currentDirectory, '/home/user/Documents');
    expect(state.contents.length, 2); // report.txt, notes.txt
  });

  test('goUp navigates to parent directory', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user/Documents');
    await notifier.goUp();

    final state = container.read(filePickerProvider).value;
    expect(state!.currentDirectory, '/home/user');
  });

  test('goBack and goForward navigate history', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user');
    await notifier.goToDirectory('/home/user/Documents');
    await notifier.goToDirectory('/home/user/Downloads');

    await notifier.goBack();
    var state = container.read(filePickerProvider).value;
    expect(state!.currentDirectory, '/home/user/Documents');

    await notifier.goForward();
    state = container.read(filePickerProvider).value;
    expect(state!.currentDirectory, '/home/user/Downloads');
  });

  test('toggleHiddenFiles shows/hides hidden files', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user');
    
    await notifier.toggleHiddenFiles();
    var state = container.read(filePickerProvider).value;
    expect(state!.showHiddenFiles, isTrue);
    expect(state.contents.length, 7); // includes .hidden_file

    await notifier.toggleHiddenFiles();
    state = container.read(filePickerProvider).value;
    expect(state!.showHiddenFiles, isFalse);
    expect(state.contents.length, 6);
  });

  test('toggleSelection adds/removes items from selection', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user/Documents');
    
    // Normal select
    notifier.toggleSelection('/home/user/Documents/report.txt');
    var state = container.read(filePickerProvider).value;
    expect(state!.selection.contains('/home/user/Documents/report.txt'), isTrue);

    // Ctrl+Select (add)
    notifier.toggleSelection('/home/user/Documents/notes.txt', isCtrl: true);
    state = container.read(filePickerProvider).value;
    expect(state!.selection.length, 2);

    // Ctrl+Select (remove)
    notifier.toggleSelection('/home/user/Documents/report.txt', isCtrl: true);
    state = container.read(filePickerProvider).value;
    expect(state!.selection.length, 1);
    expect(state.selection.contains('/home/user/Documents/notes.txt'), isTrue);
  });

  test('toggleSelection with Shift selects range', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/home/user');
    
    // Select Desktop (index 0 usually)
    notifier.toggleSelection('/home/user/Desktop');
    
    // Shift+Select Downloads (index 2)
    notifier.toggleSelection('/home/user/Downloads', isShift: true);
    final state = container.read(filePickerProvider).value;
    expect(state!.selection.length, 3); // Desktop, Documents, Downloads
  });

  test('clearError resets error state', () async {
    final notifier = container.read(filePickerProvider.notifier);
    await notifier.initialize(initialDirectory: '/does/not/exist');
    
    var state = container.read(filePickerProvider).value;
    expect(state!.error, isNotNull);

    notifier.clearError();
    state = container.read(filePickerProvider).value;
    expect(state!.error, isNull);
  });
}
