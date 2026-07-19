import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/track_selector_menu.dart';

void main() {
  testWidgets('TrackSelectorMenu renders and selects tracks', (WidgetTester tester) async {
    dynamic selectedTrack;
    final audioTrack = AudioTrack.auto();


    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackSelectorMenu(
            title: 'Audio',
            audioTracks: [audioTrack, AudioTrack.no()],
            selectedTrack: audioTrack,
            onTrackSelected: (track) {
              selectedTrack = track;
            },
          ),
        ),
      ),
    );

    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    await tester.tap(find.text('None'));
    await tester.pump();

    expect(selectedTrack, isA<AudioTrack>());
  });

  testWidgets('TrackSelectorMenu shows Load External button only when provided', (WidgetTester tester) async {
    var didTapLoadExternal = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackSelectorMenu(
            title: 'Subtitle',
            selectedTrack: SubtitleTrack.auto(),
            onTrackSelected: (_) {},
            onLoadExternal: () {
              didTapLoadExternal = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Load External Subtitle'), findsOneWidget);
    await tester.tap(find.text('Load External Subtitle'));
    expect(didTapLoadExternal, true);
  });

  testWidgets('TrackSelectorMenu handles specific track properties', (WidgetTester tester) async {
    final specificTrack = AudioTrack('1', 'Eng', 'English');
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackSelectorMenu(
            title: 'Audio',
            audioTracks: [specificTrack],
            selectedTrack: specificTrack,
            onTrackSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Eng'), findsOneWidget);
  });
}
