import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';

void main() {
  test('AppSettings should have openInStandaloneMode set to true by default', () {
    const settings = AppSettings();
    expect(settings.openInStandaloneMode, true);
  });
  
  test('AppSettings copyWith properly updates openInStandaloneMode', () {
    const settings = AppSettings();
    final updated = settings.copyWith(openInStandaloneMode: false);
    expect(updated.openInStandaloneMode, false);
  });
}
