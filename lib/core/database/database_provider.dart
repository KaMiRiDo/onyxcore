import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Global singleton provider for the [AppDatabase].
///
/// Initialized once in [main] via [ProviderScope] overrides:
/// ```dart
/// final db = AppDatabase();
/// runWidget(ProviderScope(
///   overrides: [databaseProvider.overrideWithValue(db)],
///   child: const OnyxCoreMultiViewApp(),
/// ));
/// ```
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
