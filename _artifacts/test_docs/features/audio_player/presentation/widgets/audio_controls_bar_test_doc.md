# Audio Controls Bar Test Document

### 1. Unit Test Plan Format
N/A - Pure Presentation Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-CTRL-01 | audio_controls_bar.dart | AudioControlsBar | toggle favorite state when favorite icon is tapped | Mock currentTrackProvider and audioFavoritesProvider | Tap the favorite IconButton | verify AudioFavoritesNotifier.toggleFavorite is called |
| W-AUD-CTRL-02 | audio_controls_bar.dart | AudioControlsBar | toggle mute state when volume icon is tapped | Mock audioVolumeProvider (e.g. 100), Mock Player | Tap the volume Icon | verify Player.setVolume(0) is called |
| W-AUD-CTRL-03 | audio_controls_bar.dart | AudioControlsBar | restore volume when mute icon is tapped | Mock audioVolumeProvider (0), Mock Player | Tap the volume Icon | verify Player.setVolume(100) is called |
| W-AUD-CTRL-04 | audio_controls_bar.dart | AudioControlsBar | change volume when slider is dragged | Mock Player, set volume to 50 | Drag volume Slider to new value (e.g. 150) | verify Player.setVolume(150) is called |
| W-AUD-CTRL-05 | audio_controls_bar.dart | AudioControlsBar | play previous track when skip previous is tapped | Mock Player | Tap skip_previous IconButton | verify Player.previous() is called |
| W-AUD-CTRL-06 | audio_controls_bar.dart | AudioControlsBar | play next track when skip next is tapped | Mock Player | Tap skip_next IconButton | verify Player.next() is called |
| W-AUD-CTRL-07 | audio_controls_bar.dart | AudioControlsBar | toggle play/pause when play/pause button is tapped | Mock Player | Tap play/pause container | verify Player.playOrPause() is called |
| W-AUD-CTRL-08 | audio_controls_bar.dart | AudioControlsBar | render pause icon when playing | Mock audioPlayingProvider to emit true | Render widget | Finds Icons.pause_rounded |
| W-AUD-CTRL-09 | audio_controls_bar.dart | AudioControlsBar | render play icon when paused | Mock audioPlayingProvider to emit false | Render widget | Finds Icons.play_arrow_rounded |
