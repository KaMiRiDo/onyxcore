# Audio Controls Bar Test Document

### 1. Unit Test Plan Format
N/A - Pure Presentation Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-CTRL-01 | audio_controls_bar.dart | AudioControlsBar | toggle favorite state when favorite icon is tapped | Mock currentTrackProvider with a track, audioFavoritesProvider empty | Tap the favorite IconButton | verify AudioFavoritesNotifier.toggleFavorite is called with track path |
| W-AUD-CTRL-02 | audio_controls_bar.dart | AudioControlsBar | display filled magenta heart when track is a favorite | Mock currentTrack path in audioFavoritesProvider | Render widget | Finds Icons.favorite_rounded with AppColors.magenta color |
| W-AUD-CTRL-03 | audio_controls_bar.dart | AudioControlsBar | display outline white70 heart when track is not a favorite | Mock currentTrack path NOT in audioFavoritesProvider | Render widget | Finds Icons.favorite_border_rounded with Colors.white70 |
| W-AUD-CTRL-04 | audio_controls_bar.dart | AudioControlsBar | show SizedBox placeholder when no current track | Mock currentTrackProvider returning null | Render widget | Finds SizedBox with width 48, no favorite icon |
| W-AUD-CTRL-05 | audio_controls_bar.dart | AudioControlsBar | toggle mute when volume icon is tapped from audible | Mock Player with volume=100 | Tap the volume GestureDetector | verify Player.setVolume(0) is called |
| W-AUD-CTRL-06 | audio_controls_bar.dart | AudioControlsBar | toggle unmute when volume icon is tapped from muted | Mock Player with volume=0 | Tap the volume GestureDetector | verify Player.setVolume(100) is called |
| W-AUD-CTRL-07 | audio_controls_bar.dart | AudioControlsBar | display volume_off icon when volume is 0 | Mock audioVolumeProvider emitting 0 | Render widget | Finds Icons.volume_off_rounded |
| W-AUD-CTRL-08 | audio_controls_bar.dart | AudioControlsBar | display volume_up icon when volume is above 0 | Mock audioVolumeProvider emitting 75 | Render widget | Finds Icons.volume_up_rounded |
| W-AUD-CTRL-09 | audio_controls_bar.dart | AudioControlsBar | change volume when slider is dragged | Mock Player, set volume to 50 | Drag volume Slider to new value (e.g. 150) | verify Player.setVolume(150) is called |
| W-AUD-CTRL-10 | audio_controls_bar.dart | AudioControlsBar | clamp slider range to 0-200 | Mock audioVolumeProvider emitting 100 | Render slider | verify Slider min=0, max=200 |
| W-AUD-CTRL-11 | audio_controls_bar.dart | AudioControlsBar | turn slider track magenta when volume exceeds 100 | Mock audioVolumeProvider emitting 150 | Render widget | verify SliderTheme activeTrackColor is AppColors.magenta |
| W-AUD-CTRL-12 | audio_controls_bar.dart | AudioControlsBar | keep slider track white when volume is at or below 100 | Mock audioVolumeProvider emitting 75 | Render widget | verify SliderTheme activeTrackColor is Colors.white |
| W-AUD-CTRL-13 | audio_controls_bar.dart | AudioControlsBar | turn slider thumb magenta when volume exceeds 100 | Mock audioVolumeProvider emitting 150 | Render widget | verify SliderTheme thumbColor is AppColors.magenta |
| W-AUD-CTRL-14 | audio_controls_bar.dart | AudioControlsBar | display correct volume percentage text | Mock audioVolumeProvider emitting 75.4 | Render widget | Finds Text widget '75%' (toInt) in 36px-wide SizedBox |
| W-AUD-CTRL-15 | audio_controls_bar.dart | AudioControlsBar | display 0% when muted | Mock audioVolumeProvider emitting 0 | Render widget | Finds Text '0%' |
| W-AUD-CTRL-16 | audio_controls_bar.dart | AudioControlsBar | display 200% at max volume | Mock audioVolumeProvider emitting 200 | Render widget | Finds Text '200%' |
| W-AUD-CTRL-17 | audio_controls_bar.dart | AudioControlsBar | play previous track when skip previous is tapped | Mock Player | Tap skip_previous IconButton | verify Player.previous() is called |
| W-AUD-CTRL-18 | audio_controls_bar.dart | AudioControlsBar | play next track when skip next is tapped | Mock Player | Tap skip_next IconButton | verify Player.next() is called |
| W-AUD-CTRL-19 | audio_controls_bar.dart | AudioControlsBar | toggle play/pause when play/pause container is tapped | Mock Player | Tap play/pause GestureDetector | verify Player.playOrPause() is called |
| W-AUD-CTRL-20 | audio_controls_bar.dart | AudioControlsBar | render pause icon when playing | Mock audioPlayingProvider to emit true | Render widget | Finds Icons.pause_rounded with black color |
| W-AUD-CTRL-21 | audio_controls_bar.dart | AudioControlsBar | render play icon when paused | Mock audioPlayingProvider to emit false | Render widget | Finds Icons.play_arrow_rounded with black color |
| W-AUD-CTRL-22 | audio_controls_bar.dart | AudioControlsBar | render play/pause button with correct dimensions | Render widget | Mount widget | verify play/pause Container has width=64, height=48, borderRadius=16 |
| W-AUD-CTRL-23 | audio_controls_bar.dart | AudioControlsBar | render play/pause button with white background | Render widget | Mount widget | verify play/pause Container color is Colors.white |
| W-AUD-CTRL-24 | audio_controls_bar.dart | AudioControlsBar | render skip icons at 32px size | Render widget | Mount widget | verify skip_previous and skip_next icons have size=32 |
| W-AUD-CTRL-25 | audio_controls_bar.dart | AudioControlsBar | use Stack layout for strict center alignment | Render widget | Mount widget | verify Stack is present with Alignment.center |
| W-AUD-CTRL-26 | audio_controls_bar.dart | AudioControlsBar | place 24px spacing between transport controls | Render widget | Mount widget | verify SizedBox(width: 24) between skip and play buttons |
| W-AUD-CTRL-27 | audio_controls_bar.dart | AudioControlsBar | render volume slider with 100px width | Render widget | Mount widget | verify volume Slider SizedBox width=100 |
| W-AUD-CTRL-28 | audio_controls_bar.dart | AudioControlsBar | default to volume 100 when audioVolumeProvider has no value | Mock audioVolumeProvider with no async data yet | Render widget | verify volume displays as 100%, slider at 100 |
| W-AUD-CTRL-29 | audio_controls_bar.dart | AudioControlsBar | default to not playing when audioPlayingProvider has no value | Mock audioPlayingProvider with no async data yet | Render widget | verify play icon is shown (not pause) |
| W-AUD-CTRL-30 | audio_controls_bar.dart | AudioControlsBar | handle null player gracefully (no crash on tap) | Set audioPlayerProvider to null | Tap play/pause, skip buttons | verify no exception, operations are no-ops |
