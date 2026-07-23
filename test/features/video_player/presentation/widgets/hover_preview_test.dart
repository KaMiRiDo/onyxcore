import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/hover_preview.dart';

class MockProcess implements Process {

  MockProcess({required this.stdoutStream, required this.exitCodeFuture});
  final Stream<List<int>> stdoutStream;
  final Future<int> exitCodeFuture;

  @override
  Stream<List<int>> get stdout => stdoutStream;

  @override
  Future<int> get exitCode => exitCodeFuture;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('HoverPreview handles process extraction and UI updates correctly', (WidgetTester tester) async {
    final notifier = ValueNotifier<double?>(null);
    var processStartCount = 0;

    Future<Process> mockProcessStart(String exec, List<String> args) async {
      processStartCount++;
      // Return a 1x1 fake transparent PNG bytes or any small bytes
      final fakeImage = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
        0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 
        0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 
        0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 
        0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);
      
      final stdoutController = StreamController<List<int>>()
        ..add(fakeImage);
      stdoutController.close().ignore();

      return MockProcess(
        stdoutStream: stdoutController.stream,
        exitCodeFuture: Future.value(0),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoverPreview(
            mediaPath: 'test.mp4',
            totalDuration: const Duration(seconds: 10),
            sliderWidth: 100,
            hoverXNotifier: notifier,
            isVisible: true,
            processStart: mockProcessStart,
          ),
        ),
      ),
    );

    // Initial state: invisible because hoverX is null
    expect(find.byType(HoverPreview), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
    expect(find.text('00:05'), findsNothing);

    // Trigger hover
    notifier.value = 50.0;
    
    // The pump will fire the microtask that executes mockProcessStart
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    
    // Should show 00:05 and Image
    expect(find.text('00:05'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(processStartCount, 1);

    // Queue another hover update while extraction is happening (simulated by rapid updates)
    // Actually, since process is fast, we can test rapid updates
    notifier
      ..value = 60.0
      ..value = 70.0;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    
    expect(find.text('00:07'), findsOneWidget);
    // processStartCount should be at least 2
    expect(processStartCount, greaterThanOrEqualTo(2));

    // Change media path to test process kill and reset
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoverPreview(
            mediaPath: 'test2.mp4', // Changed
            totalDuration: const Duration(seconds: 10),
            sliderWidth: 100,
            hoverXNotifier: notifier,
            isVisible: true,
            processStart: mockProcessStart,
          ),
        ),
      ),
    );
    
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('HoverPreview handles ffmpeg error gracefully', (WidgetTester tester) async {
    final notifier = ValueNotifier<double?>(null);
    Future<Process> mockProcessStart(String exec, List<String> args) async {
      final stdoutController = StreamController<List<int>>()
        ..add([]);
      stdoutController.close().ignore();

      return MockProcess(
        stdoutStream: stdoutController.stream,
        exitCodeFuture: Future.value(1), // Error exit code
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoverPreview(
            mediaPath: 'test.mp4',
            totalDuration: const Duration(seconds: 10),
            sliderWidth: 100,
            hoverXNotifier: notifier,
            isVisible: true,
            processStart: mockProcessStart,
          ),
        ),
      ),
    );

    notifier.value = 10.0; // Trigger
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    // Shows CircularProgressIndicator because bytes are null
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
