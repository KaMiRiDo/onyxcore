import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_missing_binaries_view.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';

class MockDownloaderUpdateNotifier extends DownloaderUpdateNotifier {

  MockDownloaderUpdateNotifier(this._state);
  final DownloaderUpdateState _state;

  @override
  DownloaderUpdateState build() => _state;



  @override
  Future<void> updateBinaries() async {}

  @override
  Future<void> checkForUpdates({bool clearError = true}) async {}
  
  @override
  Future<void> updateEngine(dynamic engine) async {}
  
  @override
  Future<void> installProcessEngine(dynamic engine, Future<dynamic>? processFuture, {bool isRemoving = false}) async {}
}

void main() {
  group('DownloadsMissingBinariesView Tests', () {
    testWidgets('Shows Install button when not updating', (tester) async {
      final mockNotifier = MockDownloaderUpdateNotifier(
        const DownloaderUpdateState(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloaderUpdateProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsMissingBinariesView(),
            ),
          ),
        ),
      );

      expect(find.text('Install Dependencies'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Shows currentUpdatingEngineName in progress UI during update', (tester) async {
      final mockNotifier = MockDownloaderUpdateNotifier(
        const DownloaderUpdateState(
          isUpdating: true,
          progress: 0.45,
          currentUpdatingEngineName: 'yt-dlp',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloaderUpdateProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsMissingBinariesView(),
            ),
          ),
        ),
      );

      expect(find.text('Install Dependencies'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Installing yt-dlp... 45%'), findsOneWidget);
    });

    testWidgets('Shows generic progress text if currentUpdatingEngineName is null', (tester) async {
      final mockNotifier = MockDownloaderUpdateNotifier(
        const DownloaderUpdateState(
          isUpdating: true,
          progress: 0.60,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloaderUpdateProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsMissingBinariesView(),
            ),
          ),
        ),
      );

      expect(find.text('Installing... 60%'), findsOneWidget);
    });
  });
}
