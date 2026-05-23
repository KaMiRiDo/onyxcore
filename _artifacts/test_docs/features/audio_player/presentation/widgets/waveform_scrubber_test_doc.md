# Waveform Scrubber Test Document

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-AUD-WAVE-01 | waveform_scrubber.dart | WaveformPainter.shouldRepaint | return true when progress changes | Create two painters with different progress values | Call shouldRepaint | Returns true |
| U-AUD-WAVE-02 | waveform_scrubber.dart | WaveformPainter.shouldRepaint | return true when barCount changes | Create two painters with different barCount values | Call shouldRepaint | Returns true |
| U-AUD-WAVE-03 | waveform_scrubber.dart | WaveformPainter.shouldRepaint | return false when progress and barCount are the same | Create two painters with identical values | Call shouldRepaint | Returns false |
| U-AUD-WAVE-04 | waveform_scrubber.dart | WaveformPainter.shouldRepaint | return false when only seed changes | Create two painters with same progress/barCount but different seed | Call shouldRepaint | Returns false (seed doesn't trigger repaint) |
| U-AUD-WAVE-05 | waveform_scrubber.dart | WaveformPainter.paint | generate deterministic bar heights from seed | Create WaveformPainter with seed=42 | Call paint twice with same seed | Both invocations produce identical bar layout |
| U-AUD-WAVE-06 | waveform_scrubber.dart | WaveformPainter.paint | generate different bar heights for different seeds | Create two WaveformPainters with seed=42 and seed=99 | Call paint on both | Bar patterns are different |
| U-AUD-WAVE-07 | waveform_scrubber.dart | WaveformPainter.paint | use gradient shader (magenta→violet) for played bars | Provide progress=0.5 | Inspect playedPaint | verify LinearGradient with AppColors.magenta and AppColors.violet |
| U-AUD-WAVE-08 | waveform_scrubber.dart | WaveformPainter.paint | use white 20% opacity for unplayed bars | Provide progress=0.5 | Inspect unplayedPaint | verify color is Colors.white.withOpacity(0.2) |
| U-AUD-WAVE-09 | waveform_scrubber.dart | WaveformPainter.paint | draw white playhead indicator at current progress | Provide progress=0.5 | Inspect playheadPaint | verify color is Colors.white, indicator drawn at progress position |
| U-AUD-WAVE-10 | waveform_scrubber.dart | WaveformPainter.paint | calculate bar height between 10 and size.height | Provide size height=60 | Call paint | All bar heights are between 10.0 and 60.0 |
| U-AUD-WAVE-11 | waveform_scrubber.dart | _formatDuration | format zero duration | Duration.zero | Call _formatDuration | Returns "0:00" |
| U-AUD-WAVE-12 | waveform_scrubber.dart | _formatDuration | format duration with seconds < 10 (pad with zero) | Duration(seconds: 65) | Call _formatDuration | Returns "1:05" |
| U-AUD-WAVE-13 | waveform_scrubber.dart | _formatDuration | format multi-minute duration | Duration(seconds: 725) | Call _formatDuration | Returns "12:05" |

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-WAVE-01 | waveform_scrubber.dart | WaveformScrubber | seek to correct position on tap | Mock Player, duration: 100s, layout width: 200px | Tap exactly in the middle of the scrubber (x=100) | verify Player.seek(50s) is called |
| W-AUD-WAVE-02 | waveform_scrubber.dart | WaveformScrubber | clamp tap seek to start (0) when tapping at x=0 | Mock Player, duration: 100s | Tap at x=0 | verify Player.seek(0s) |
| W-AUD-WAVE-03 | waveform_scrubber.dart | WaveformScrubber | clamp tap seek to end when tapping at max width | Mock Player, duration: 100s, width: 200px | Tap at x=200 | verify Player.seek(100s) |
| W-AUD-WAVE-04 | waveform_scrubber.dart | WaveformScrubber | not seek when duration is zero | Mock Player, duration: 0s | Tap anywhere | verify Player.seek NOT called |
| W-AUD-WAVE-05 | waveform_scrubber.dart | WaveformScrubber | not seek when player is null | audioPlayerProvider=null, duration: 100s | Tap anywhere | verify no crash, no seek |
| W-AUD-WAVE-06 | waveform_scrubber.dart | WaveformScrubber | capture anchor position on drag start | Mock Player at position 20s, duration: 100s | Start horizontal drag | verify _scrubAnchor is set to 20s, _virtualScrubPosition is 20s |
| W-AUD-WAVE-07 | waveform_scrubber.dart | WaveformScrubber | not start drag when duration is zero | Mock Player, duration: 0s | Start horizontal drag | verify _scrubAnchor remains null |
| W-AUD-WAVE-08 | waveform_scrubber.dart | WaveformScrubber | update virtual position and seek on drag update | Mock Player position: 20s, duration: 100s, width: 100px | Start drag, then drag 10px right (delta.dx=10) | verify _virtualScrubPosition updates to ~30s, Player.seek(~30s) called |
| W-AUD-WAVE-09 | waveform_scrubber.dart | WaveformScrubber | accumulate drag delta across multiple updates | Mock Player position: 50s, width: 100px, duration: 100s | Start drag, drag 5px, then drag 5px more | verify cumulative 10px produces seek at ~60s |
| W-AUD-WAVE-10 | waveform_scrubber.dart | WaveformScrubber | clamp seek position to 0 on left overflow | Mock Player position: 5s, width: 100px, duration: 100s | Drag left by -50px | verify Player.seek clamped to Duration.zero |
| W-AUD-WAVE-11 | waveform_scrubber.dart | WaveformScrubber | clamp seek position to duration on right overflow | Mock Player position: 95s, width: 100px, duration: 100s | Drag right by +50px | verify Player.seek clamped to 100s |
| W-AUD-WAVE-12 | waveform_scrubber.dart | WaveformScrubber | clear virtual position on drag end | Mock Player, mid-drag state | End horizontal drag | verify _virtualScrubPosition is null, _scrubAnchor is null, _scrubDragAccumulator is 0.0 |
| W-AUD-WAVE-13 | waveform_scrubber.dart | WaveformScrubber | clear virtual position on drag cancel | Mock Player, mid-drag state | Cancel horizontal drag | verify _virtualScrubPosition is null |
| W-AUD-WAVE-14 | waveform_scrubber.dart | WaveformScrubber | display UI from virtual position during drag | Mid-drag with _virtualScrubPosition=60s, engine position=20s | Render widget | verify displayed time text shows "1:00" (60s), not "0:20" |
| W-AUD-WAVE-15 | waveform_scrubber.dart | WaveformScrubber | display correct current and remaining time strings | Mock position to 65s, duration to 125s | Render widget | Finds "1:05" and "-1:00" |
| W-AUD-WAVE-16 | waveform_scrubber.dart | WaveformScrubber | display "0:00" and "-0:00" when both position and duration are zero | Mock position 0s, duration 0s | Render widget | Finds "0:00" for both elapsed and remaining |
| W-AUD-WAVE-17 | waveform_scrubber.dart | WaveformScrubber | handle zero duration safely without DivisionByZero | Mock duration to 0s | Render widget | verify progress is 0.0 and no exceptions occur |
| W-AUD-WAVE-18 | waveform_scrubber.dart | WaveformScrubber | calculate bar count dynamically from width | Mock width: 250px (barWidth=3, gap=2) | Render widget | verify barCount = floor(250 / 5) = 50 |
| W-AUD-WAVE-19 | waveform_scrubber.dart | WaveformScrubber | render waveform inside 60px height SizedBox | Render widget | Mount widget | Finds SizedBox with height=60 |
| W-AUD-WAVE-20 | waveform_scrubber.dart | WaveformScrubber | render time labels with white70 color, 12px font | Render widget | Mount widget | verify both time Text widgets have color Colors.white70, fontSize 12 |
| W-AUD-WAVE-21 | waveform_scrubber.dart | WaveformScrubber | prepend "-" to remaining time text | Mock position 30s, duration 60s | Render widget | verify remaining time shows "-0:30" (with dash prefix) |
| W-AUD-WAVE-22 | waveform_scrubber.dart | WaveformScrubber | ignore drag update when _scrubAnchor is null | Mock Player, no drag started | Send drag update event | verify no seek, no crash |
| W-AUD-WAVE-23 | waveform_scrubber.dart | WaveformScrubber | use fileName.hashCode as seed for WaveformPainter | Render with fileName="test.mp3" | Mount widget | verify WaveformPainter created with seed = "test.mp3".hashCode |
| W-AUD-WAVE-24 | waveform_scrubber.dart | WaveformScrubber | default position/duration to Duration.zero when providers have no value | Both providers in loading state (no value) | Render widget | verify progress=0.0, displayed as "0:00" / "-0:00" |
