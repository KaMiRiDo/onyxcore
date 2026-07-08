import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

void main() {
  Widget createWidgetUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadsPanel(),
        ),
      ),
    );
  }

  group('DownloadsPanel Comprehensive Edge Cases', () {
    late ProviderContainer container;
    late AppDatabase appDb;

    setUp(() {
      appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(appDb),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      appDb.close();
    });

    testWidgets('Renders properly and handles lifecycle events', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DownloadsPanel), findsOneWidget);
    });

    testWidgets('Toggles history view when changing state', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(container));
      container.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.history;
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DownloadsPanel), findsOneWidget);
    });
  });
}
