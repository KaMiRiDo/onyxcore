import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Startup Sequence', () {
    test('OnyxCoreApp calls checkForUpdates but not updateBinaries on init', () {
      final file = File('lib/app.dart');
      final content = file.readAsStringSync();
      
      // Ensure that we are calling checkForUpdates
      expect(content.contains('notifier.checkForUpdates()'), isTrue, 
        reason: 'OnyxCoreApp should check for updates on startup');
      
      // Ensure that we are NOT calling updateBinaries or updateAll
      expect(content.contains('notifier.updateBinaries()'), isFalse,
        reason: 'OnyxCoreApp should NOT automatically download binaries on startup');
      expect(content.contains('notifier.updateAll('), isFalse,
        reason: 'OnyxCoreApp should NOT automatically download all binaries on startup');
    });
  });
}
