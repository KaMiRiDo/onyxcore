import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_missing_binaries_view.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/downloader/services/engines/gallery_dl_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/ytdlp_engine.dart';

class MockDownloaderUpdateNotifier extends DownloaderUpdateNotifier {
  @override
  DownloaderUpdateState build() => const DownloaderUpdateState();

  @override
  Future<void> updateBinaries() async {
    state = state.copyWith(isUpdating: true, progress: 0.1);
  }

  void setState(DownloaderUpdateState newState) {
    state = newState;
  }
}

class MockErrorDownloaderUpdateNotifier extends DownloaderUpdateNotifier {
  @override
  DownloaderUpdateState build() => const DownloaderUpdateState(error: 'Network failure');
}

class MissingYtDlpEngine extends YtDlpEngine {
  @override
  bool get isInstalled => false;
}

class MissingGalleryDlEngine extends GalleryDlEngine {
  @override
  bool get isInstalled => false;
}

void main() {
  setUp(() {
    EngineRegistry.clearAllEnginesForTesting();
    EngineRegistry.register(MissingYtDlpEngine());
    EngineRegistry.register(MissingGalleryDlEngine());
  });

  tearDown(EngineRegistry.clearAllEnginesForTesting);

  Widget buildWidget(WidgetRef ref) {
    return const MaterialApp(
      home: Scaffold(
        body: DownloadsMissingBinariesView(onCheckBinaries: _mockCheck),
      ),
    );
  }

  group('DownloadsMissingBinariesView Tests', () {
    testWidgets('renders missing required engines', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloaderUpdateProvider.overrideWith(MockDownloaderUpdateNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsMissingBinariesView(onCheckBinaries: _mockCheck),
            ),
          ),
        ),
      );

      debugPrint('Missing: ${EngineRegistry.requiredEngines.where((e) => !e.isInstalled).map((e) => e.displayName).join(", ")}');
      expect(find.text('Required Dependencies Missing'), findsOneWidget);
      expect(find.text('Missing: gallery-dl, yt-dlp'), findsOneWidget);
      expect(find.text('Download Required Engines'), findsOneWidget);
    });

    testWidgets('shows progress when updating', (tester) async {
      final mockService = MockDownloaderUpdateNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloaderUpdateProvider.overrideWith(() => mockService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsMissingBinariesView(onCheckBinaries: _mockCheck),
            ),
          ),
        ),
      );

      // Tap the download button
      await tester.tap(find.text('Download Required Engines'));
      await tester.pump();

      // Should show progress indicator and progress text
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('10% downloaded'), findsOneWidget);
      expect(find.text('Download Required Engines'), findsNothing);
    });
    
    testWidgets('shows error state when update fails', (tester) async {
      final mockService = MockErrorDownloaderUpdateNotifier();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloaderUpdateProvider.overrideWith(() => mockService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsMissingBinariesView(onCheckBinaries: _mockCheck),
            ),
          ),
        ),
      );

      expect(find.text('Error: Network failure'), findsOneWidget);
      expect(find.text('Download Required Engines'), findsOneWidget); // Button should still be there
    });
  });
}

void _mockCheck() {}
