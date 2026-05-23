# Hero Audio Player Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-HERO-01 | hero_audio_player.dart | HeroAudioPlayer | display current track info and album art | Mock currentTrackProvider with tag containing image | Render widget | Finds image widget, artist text, album text |
| W-AUD-HERO-02 | hero_audio_player.dart | HeroAudioPlayer | fallback to default icon if no album art | Mock currentTrackProvider with tag lacking image | Render widget | Finds default Icons.music_note_rounded |
| W-AUD-HERO-03 | hero_audio_player.dart | HeroAudioPlayer | display auto-scrolling text for long titles | Mock long track title | Render widget | Finds AutoScrollingText widget |
| W-AUD-HERO-04 | hero_audio_player.dart | AutoScrollingText | initialize scrolling after delay | Render AutoScrollingText with long text | Wait 2 seconds | verify scroll controller starts jumping |
| W-AUD-HERO-05 | hero_audio_player.dart | AutoScrollingText | reset scroll when text changes | Render AutoScrollingText, update text | Update widget | verify scroll controller resets to 0 |
