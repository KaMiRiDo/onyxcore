import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

Future<SharedPreferences> getMockPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return await SharedPreferences.getInstance();
}

MockSettingsRepository getMockSettingsRepo() {
  final mockSettingsRepository = MockSettingsRepository();
  when(() => mockSettingsRepository.load()).thenAnswer((_) async => AppSettings());
  when(() => mockSettingsRepository.getFolderSort(any(), any())).thenReturn(SortOption.aToZ);
  when(() => mockSettingsRepository.setFolderSort(any(), any())).thenAnswer((_) async {});
  return mockSettingsRepository;
}
