import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

AppDatabase getMockDb() {
  return AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
}

MockSettingsRepository getMockSettingsRepo() {
  final mockSettingsRepository = MockSettingsRepository();
  when(mockSettingsRepository.load).thenAnswer((_) async => AppSettings());
  when(
    () => mockSettingsRepository.setFolderSort(any(), any()),
  ).thenAnswer((_) async {});
  return mockSettingsRepository;
}
