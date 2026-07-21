import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/presentation/lifecycle/player_initializer.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

class MockPlayer extends Mock implements Player {}
class MockPlatform extends Mock implements PlatformPlayer {
  final Map<String, String> properties = {};
  
  @override
  Future<void> setProperty(String property, String value) async {
    properties[property] = value;
  }
}

class MockSettingsNotifier extends SettingsNotifier {
  final AppSettings settings;
  MockSettingsNotifier(this.settings);
  
  @override
  Future<AppSettings> build() async => settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('PlayerInitializer', () {
    late MockPlayer mockPlayer;
    late MockPlatform mockPlatform;

    Future<WidgetRef> getTestRef(WidgetTester tester, AppSettings settings) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => MockSettingsNotifier(settings)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      // Wait for async initialization
      await tester.pumpAndSettle();
      // Ensure settings are loaded
      await capturedRef.read(settingsProvider.future);
      return capturedRef;
    }

    setUp(() {
      mockPlayer = MockPlayer();
      mockPlatform = MockPlatform();
      when(() => mockPlayer.platform).thenReturn(mockPlatform);
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
      
      // Mock path_provider channel to prevent hanging during getTemporaryDirectory()
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getTemporaryDirectory') {
            return '.';
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

    testWidgets('configures local stream settings correctly', (tester) async {
      final ref = await getTestRef(tester, const AppSettings());

      await PlayerInitializer.configure(
        player: mockPlayer,
        isNetworkStream: false,
        initParams: null,
        ref: ref,
      );

      // Local sliding window
      expect(mockPlatform.properties['demuxer-readahead-secs'], equals('60'));
      expect(mockPlatform.properties['demuxer-max-bytes'], equals('419430400'));
      expect(mockPlatform.properties['cache-pause'], equals('no'));

      // Shared settings
      expect(mockPlatform.properties['hr-seek'], equals('yes'));
      expect(mockPlatform.properties['vd-lavc-dr'], equals('no'));
      expect(mockPlatform.properties['hwdec'], equals('vaapi,nvdec,vdpau,auto-safe'));
      
      verify(() => mockPlayer.setVolume(30.0)).called(1);
    });

    testWidgets('configures network stream settings correctly with yt-dlp params', (tester) async {
      final ref = await getTestRef(tester, const AppSettings());

      await PlayerInitializer.configure(
        player: mockPlayer,
        isNetworkStream: true,
        initParams: {
          'selectedFormatId': '137',
          'audioUrl': 'https://example.com/audio.m4a',
        },
        ref: ref,
      );

      // Network settings
      expect(mockPlatform.properties['ytdl-format'], equals('137+bestaudio/best'));
      expect(mockPlatform.properties['audio-file'], equals('https://example.com/audio.m4a'));
      expect(mockPlatform.properties['demuxer-readahead-secs'], equals('120'));
      expect(mockPlatform.properties['cache-pause'], equals('yes'));
    });

    testWidgets('configures network stream without initParams', (tester) async {
      final ref = await getTestRef(tester, const AppSettings());

      await PlayerInitializer.configure(
        player: mockPlayer,
        isNetworkStream: true,
        initParams: null,
        ref: ref,
      );

      // Default yt-dlp
      expect(mockPlatform.properties['ytdl-format'], equals('bestvideo+bestaudio/best'));
    });

    testWidgets('configures hwdec when auto and cached is available', (tester) async {
      final ref = await getTestRef(tester, const AppSettings(
        selectedHwDec: 'auto',
        cachedResolvedHwDec: 'vaapi',
      ));

      await PlayerInitializer.configure(
        player: mockPlayer,
        isNetworkStream: false,
        initParams: null,
        ref: ref,
      );

      expect(mockPlatform.properties['hwdec'], equals('vaapi'));
    });

    testWidgets('configures hwdec when manual selection', (tester) async {
      final ref = await getTestRef(tester, const AppSettings(
        selectedHwDec: 'nvdec',
      ));

      await PlayerInitializer.configure(
        player: mockPlayer,
        isNetworkStream: false,
        initParams: null,
        ref: ref,
      );

      expect(mockPlatform.properties['hwdec'], equals('nvdec'));
    });

    testWidgets('skips configuration if platform is null', (tester) async {
      when(() => mockPlayer.platform).thenReturn(null);
      final ref = await getTestRef(tester, const AppSettings());

      await PlayerInitializer.configure(
        player: mockPlayer,
        isNetworkStream: false,
        initParams: null,
        ref: ref,
      );

      expect(mockPlatform.properties.isEmpty, isTrue);
    });
  });
}
