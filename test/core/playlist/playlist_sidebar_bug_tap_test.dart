import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/playlist_sidebar.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  late AppDatabase db;

  setUpAll(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
  });

  final dummyFile1 = FileItem(
    name: 'test.mp3',
    path: '/music/test.mp3',
    type: FileItemType.audio,
    modified: DateTime.now(),
  );

  Widget buildTestWidget({List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db), ...overrides.cast()],
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(width: 300, child: PlaylistSidebar())),
      ),
    );
  }

  testWidgets(
    'Playlist single tap should trigger double tap behavior for media playback',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            audioQueueProvider.overrideWith((ref) => [dummyFile1]),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Tap the item in the list
      await tester.tap(find.text('test.mp3'));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(PlaylistSidebar));
      final container = ProviderScope.containerOf(element);

      expect(
        container.read(audioPlayingQueueProvider),
        [dummyFile1],
        reason:
            'Single tap should call onItemTap which acts as onItemDoubleTap to play the media',
      );
    },
  );
}
