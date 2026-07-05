import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/storage_indicator.dart';

void main() {
  late AppDatabase db;

  setUpAll(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
  });

  Widget buildTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: StorageIndicator(),
        ),
      ),
    );
  }

  testWidgets('StorageIndicator renders correctly and handles timer', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    await tester.pumpWidget(buildTestWidget(container));
    
    // Pump a few times to allow the Future in getDiskUsage to resolve
    await tester.pumpAndSettle();
    
    expect(find.text('SYSTEM STORAGE'), findsOneWidget);
    
    // Fast forward timer
    await tester.pump(const Duration(seconds: 4));
    
    // Trigger refresh
    container.read(refreshCountProvider.notifier).state++;
    await tester.pumpAndSettle();
  });
}
