import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/document_viewer/services/mermaid_offline_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  test('MermaidOfflineRenderer should render valid mermaid string to PNG bytes', () async {
    const code = '''
flowchart TD
    A([Start Day]) --> B{Sleepy?}
    ''';
    
    final result = await MermaidOfflineRenderer.renderToPng(code, isDarkMode: true);
    
    expect(result, isNotNull);
    expect(result!.isNotEmpty, isTrue);
    
    // Check if it's a valid PNG (starts with PNG signature: 89 50 4E 47 0D 0A 1A 0A)
    expect(result[0], 0x89);
    expect(result[1], 0x50);
    expect(result[2], 0x4E);
    expect(result[3], 0x47);
  });
}
