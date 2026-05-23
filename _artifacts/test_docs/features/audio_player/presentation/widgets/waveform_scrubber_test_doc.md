# Waveform Scrubber Test Document

### 1. Unit Test Plan Format
N/A - Pure Presentation Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-WAVE-01 | waveform_scrubber.dart | WaveformScrubber | seek to correct position on tap | Mock Player, duration: 100s, width: 200px | Tap exactly in the middle of the scrubber (x=100) | verify Player.seek(50s) is called |
| W-AUD-WAVE-02 | waveform_scrubber.dart | WaveformScrubber | start scrubbing without snapping back | Mock Player, position: 20s, drag start | Start horizontal drag | verify _virtualScrubPosition is set, no seek yet |
| W-AUD-WAVE-03 | waveform_scrubber.dart | WaveformScrubber | update virtual position and seek on drag update | Mock Player, duration: 100s, width: 100px | Drag horizontally by 10px | verify _virtualScrubPosition updates (+10s), verify Player.seek(30s) called |
| W-AUD-WAVE-04 | waveform_scrubber.dart | WaveformScrubber | clamp seek position to 0 and duration | Mock Player, drag out of bounds | Drag to x=-50 or x=200 | verify Player.seek is clamped to 0 or 100s |
| W-AUD-WAVE-05 | waveform_scrubber.dart | WaveformScrubber | clear virtual position on drag end | Mock Player, mid-drag state | End horizontal drag | verify _virtualScrubPosition is null |
| W-AUD-WAVE-06 | waveform_scrubber.dart | WaveformScrubber | clear virtual position on drag cancel | Mock Player, mid-drag state | Cancel horizontal drag | verify _virtualScrubPosition is null |
| W-AUD-WAVE-07 | waveform_scrubber.dart | WaveformScrubber | display correct current and remaining time strings | Mock position to 65s, duration to 125s | Render widget | Finds "1:05" and "-1:00" |
| W-AUD-WAVE-08 | waveform_scrubber.dart | WaveformScrubber | handle zero duration safely without DivisionByZero | Mock duration to 0s | Render widget | verify progress is 0.0 and no exceptions occur |
| W-AUD-WAVE-09 | waveform_scrubber.dart | WaveformScrubber | repaint waveform when progress changes | Render WaveformPainter | Update progress value | verify shouldRepaint returns true |
