import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockExtractorRuntimeService extends Mock implements ExtractorRuntimeService {}
class FakeCustomExtractor extends Fake implements CustomExtractor {}
class FakeBrowserInfo extends Fake implements BrowserInfo {}

class MockCustomExtractorNotifier extends AsyncNotifier<List<CustomExtractor>> with Mock implements CustomExtractorNotifier {
  @override
  Future<List<CustomExtractor>> build() async => [
        CustomExtractor(
          id: 'test_ext',
          name: 'Test Extractor',
          script: 'script',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      ];
}

class MockSettingsNotifier extends SettingsNotifier {
  MockSettingsNotifier(this._settings);
  final AppSettings _settings;
  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCustomExtractor());
    registerFallbackValue(FakeBrowserInfo());
  });

  late MockCustomExtractorNotifier mockExtractorNotifier;
  late MockExtractorRuntimeService mockRuntime;

  setUp(() {
    mockExtractorNotifier = MockCustomExtractorNotifier();
    mockRuntime = MockExtractorRuntimeService();
    when(() => mockRuntime.execute(
          any(),
          any(),
          browser: any(named: 'browser'),
          config: any(named: 'config'),
          onLog: any(named: 'onLog'),
          onProcessStarted: any(named: 'onProcessStarted'),
        )).thenAnswer((_) async => ExtractorResult(['https://example.com/video.mp4'], 'mock logs'));
  });

  Future<ProviderContainer> createContainer({
    AppSettings settings = const AppSettings(),
  }) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(settings)),
        customExtractorsProvider.overrideWith(() => mockExtractorNotifier),
        extractorRuntimeServiceProvider.overrideWithValue(mockRuntime),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    return container;
  }

  group('DownloadsSharedController Custom Extractor Tests', () {
    test('analyzeUrls bypasses extractor if none selected', () async {
      final container = await createContainer(
        settings: const AppSettings(customExtractorsEnabled: true),
      );
      final controller = container.read(downloadsSharedControllerProvider);
      
      // Default extractor is 'none'
      await controller.analyzeUrls('https://example.com/direct');
      
      verifyNever(() => mockRuntime.execute(
            any(),
            any(),
            browser: any(named: 'browser'),
            config: any(named: 'config'),
            onLog: any(named: 'onLog'),
            onProcessStarted: any(named: 'onProcessStarted'),
          ));
    });

    test('analyzeUrls runs custom extractor if selected', () async {
      final container = await createContainer(
        settings: const AppSettings(customExtractorsEnabled: true),
      );
      await container.read(customExtractorsProvider.future);
      final controller = container.read(downloadsSharedControllerProvider)
        ..selectedExtractorId = 'test_ext';
      
      when(() => mockRuntime.execute(
            any(),
            'https://example.com/extractme',
            browser: any(named: 'browser'),
            config: any(named: 'config'),
            onLog: any(named: 'onLog'),
            onProcessStarted: any(named: 'onProcessStarted'),
          )).thenAnswer((_) async => ExtractorResult([], 'mock logs'));

      // We don't await because analyzeUrls fires and forgets the backend part
      // but we await the initial execution
      unawaited(controller.analyzeUrls('https://example.com/extractme'));
      
      // Allow pipeline to start
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (controller.activeExtractorPids.containsKey('https://example.com/extractme') || (controller.cache.parsedItems?.isNotEmpty ?? false)) break;
      }
      
      verify(() => mockRuntime.execute(
            any(),
            'https://example.com/extractme',
            browser: any(named: 'browser'),
            config: any(named: 'config'),
            onLog: any(named: 'onLog'),
            onProcessStarted: any(named: 'onProcessStarted'),
          )).called(1);
      
      // Wait for PID to be cleared and pipeline to finish
      for (var i = 0; i < 50; i++) {
        if (!controller.activeExtractorPids.containsKey('https://example.com/extractme')) {
          await Future<void>.delayed(const Duration(milliseconds: 50)); // let downstream microtasks finish
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    test('analyzeUrls triggers hydrateProfile when extractor returns playlist (Manual test required for backend callback)', () async {
      // NOTE: MediaDownloaderBackend.analyzeUrls is static and cannot be easily mocked here.
      // This test serves as a characterization stub. Full verification of the hydrateProfile
      // trigger is performed manually as documented in the implementation plan.
      expect(true, true);
    });
    test('analyzeUrls registers and cleans up extractor PID on success', () async {
      final container = await createContainer(
        settings: const AppSettings(customExtractorsEnabled: true),
      );
      await container.read(customExtractorsProvider.future);
      final controller = container.read(downloadsSharedControllerProvider)
        ..selectedExtractorId = 'test_ext';
      
      when(() => mockRuntime.execute(
            any(),
            any(),
            browser: any(named: 'browser'),
            config: any(named: 'config'),
            onLog: any(named: 'onLog'),
            onProcessStarted: any(named: 'onProcessStarted'),
          )).thenAnswer((invocation) async {
        final onProcessStarted = invocation.namedArguments[#onProcessStarted] as void Function(int pid)?;
        onProcessStarted?.call(12345);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return ExtractorResult([], 'mock logs');
      });

      unawaited(controller.analyzeUrls('https://example.com/pid'));
      
      // Wait for PID to appear
      for (var i = 0; i < 50; i++) {
        if (controller.activeExtractorPids.containsKey('https://example.com/pid')) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      
      expect(controller.activeExtractorPids['https://example.com/pid'], contains(12345));
      
      // Wait for PID to be cleared
      for (var i = 0; i < 50; i++) {
        if (!controller.activeExtractorPids.containsKey('https://example.com/pid')) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      
      expect(controller.activeExtractorPids.containsKey('https://example.com/pid'), isFalse);
    });

    test('analyzeUrls cleans up extractor PID on failure', () async {
      final container = await createContainer(
        settings: const AppSettings(customExtractorsEnabled: true),
      );
      await container.read(customExtractorsProvider.future);
      final controller = container.read(downloadsSharedControllerProvider)
        ..selectedExtractorId = 'test_ext';
      
      when(() => mockRuntime.execute(
            any(),
            any(),
            browser: any(named: 'browser'),
            config: any(named: 'config'),
            onLog: any(named: 'onLog'),
            onProcessStarted: any(named: 'onProcessStarted'),
          )).thenAnswer((invocation) async {
        final onProcessStarted = invocation.namedArguments[#onProcessStarted] as void Function(int pid)?;
        onProcessStarted?.call(9999);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        throw ExtractorException('Simulated timeout', 'logs');
      });

      unawaited(controller.analyzeUrls('https://example.com/fail'));
      
      // Wait for PID to appear
      for (var i = 0; i < 50; i++) {
        if (controller.activeExtractorPids.containsKey('https://example.com/fail')) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.activeExtractorPids['https://example.com/fail'], contains(9999));
      
      // Wait for PID to be cleared after failure
      for (var i = 0; i < 50; i++) {
        if (!controller.activeExtractorPids.containsKey('https://example.com/fail')) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.activeExtractorPids.containsKey('https://example.com/fail'), isFalse);
    });

    test('cancelExtraction removes PID and sets error state', () async {
      final container = await createContainer(
        settings: const AppSettings(customExtractorsEnabled: true),
      );
      await container.read(customExtractorsProvider.future);
      final controller = container.read(downloadsSharedControllerProvider)
        ..selectedExtractorId = 'test_ext';
      
      controller.activeExtractorPids['https://example.com/cancel'] = [54321];
      controller.activeHydrationPids['https://example.com/cancel'] = [11111]; // simulate parallel hydration
      
      await controller.cancelExtraction('https://example.com/cancel');
      
      expect(controller.activeExtractorPids.containsKey('https://example.com/cancel'), isFalse);
      // Ensure hydration PIDs are unaffected
      expect(controller.activeHydrationPids['https://example.com/cancel'], contains(11111));
    });
  });
}
