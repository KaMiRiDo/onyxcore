import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';

void main() {
  Widget createWidgetUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DownloadHistoryDetailView(),
          ),
        ),
      ),
    );
  }

  group('DownloadHistoryDetailView Tests', () {
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

    testWidgets('Renders detail view properly with no selected id', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pumpAndSettle();

      expect(find.byType(DownloadHistoryDetailView), findsOneWidget);
    });
  });
}
