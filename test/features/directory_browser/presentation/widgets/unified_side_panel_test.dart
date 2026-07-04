import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/unified_side_panel.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/background_panel.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';

class MockDownloadsPanelWidthNotifier extends DownloadsPanelWidthNotifier {
  @override
  double build() => 300.0;
}

void main() {
  Future<void> pumpTestWidget(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('UnifiedSidePanel shows DownloadsPanel when open', (tester) async {
    await pumpTestWidget(
      tester,
      ProviderScope(
        overrides: [
          downloadsPanelWidthProvider.overrideWith(() => MockDownloadsPanelWidthNotifier()),
          downloadsPanelOpenProvider.overrideWith((ref) => true),
          backgroundPanelOpenProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          home: const Scaffold(
            body: UnifiedSidePanel(),
          ),
        ),
      ),
    );

    // The DownloadsPanel offstage widget should be visible (offstage: false)
    final offstageDownloads = tester.widget<Offstage>(
      find.byWidgetPredicate((w) => w is Offstage && w.child is DownloadsPanel)
    );
    expect(offstageDownloads.offstage, isFalse);

    final offstageBackground = tester.widget<Offstage>(
      find.byWidgetPredicate((w) => w is Offstage && w.child is BackgroundPanel)
    );
    expect(offstageBackground.offstage, isTrue);
  });

  testWidgets('UnifiedSidePanel shows BackgroundPanel when open', (tester) async {
    await pumpTestWidget(
      tester,
      ProviderScope(
        overrides: [
          downloadsPanelWidthProvider.overrideWith(() => MockDownloadsPanelWidthNotifier()),
          downloadsPanelOpenProvider.overrideWith((ref) => false),
          backgroundPanelOpenProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          home: const Scaffold(
            body: UnifiedSidePanel(),
          ),
        ),
      ),
    );

    final offstageDownloads = tester.widget<Offstage>(
      find.byWidgetPredicate((w) => w is Offstage && w.child is DownloadsPanel)
    );
    expect(offstageDownloads.offstage, isTrue);

    final offstageBackground = tester.widget<Offstage>(
      find.byWidgetPredicate((w) => w is Offstage && w.child is BackgroundPanel)
    );
    expect(offstageBackground.offstage, isFalse);
  });
}
