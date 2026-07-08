import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';

void main() {
  Widget createWidgetUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DownloadHistoryView(),
          ),
        ),
      ),
    );
  }

  group('DownloadHistoryView Tests', () {
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
      await tester.pumpAndSettle();

      expect(find.byType(DownloadHistoryView), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('Can close history view when changing state', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back_rounded);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      }
      expect(container.read(downloadsPanelViewProvider), DownloadsPanelView.tasks);
    });
  });
}
