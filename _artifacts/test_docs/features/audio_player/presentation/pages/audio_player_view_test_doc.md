# Audio Player View Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-VIEW-01 | audio_player_view.dart | AudioPlayerView | initialize providers and player on mount | Provide test audio FileItem | Mount AudioPlayerView | verify providers reset, current path set, player playlist opened |
| W-AUD-VIEW-02 | audio_player_view.dart | AudioPlayerView | pause global player on dispose if it's the active view | Render AudioPlayerView | Unmount AudioPlayerView | verify globalAudioPlayer.pause() is called |
| W-AUD-VIEW-03 | audio_player_view.dart | AudioPlayerView | apply volume boost and playlist modes on init | Render AudioPlayerView | Mount AudioPlayerView | verify volume-max=200, playlistMode=none, shuffle=false |
| W-AUD-VIEW-04 | audio_player_view.dart | AudioPlayerView | set up stream subscriptions on initialization | Mount AudioPlayerView | Emit player stream events | verify UI state updates for buffering, bitrate, and index |
| W-AUD-VIEW-05 | audio_player_view.dart | AudioPlayerView | reload directory when Ctrl+R is pressed | Render view, focus node active | Press Ctrl+R | verify directory cache invalidated, queue re-fetched |
| W-AUD-VIEW-06 | audio_player_view.dart | AudioPlayerView | toggle hidden files when Ctrl+Shift+. is pressed | Render view, hidden files false | Press Ctrl+Shift+. | verify hidden files true, queue re-fetched with hidden items |
| W-AUD-VIEW-07 | audio_player_view.dart | AudioPlayerView | select all items when Ctrl+A is pressed | Render view, queue contains 3 items | Press Ctrl+A | verify audioSelectionProvider contains all 3 items |
| W-AUD-VIEW-08 | audio_player_view.dart | AudioPlayerView | play/pause when Space is pressed | Mock Player playing=true | Press Space | verify Player.playOrPause() is called |
| W-AUD-VIEW-09 | audio_player_view.dart | AudioPlayerView | seek backward when Left Arrow is pressed | Mock Player | Press Left Arrow | verify Player.seek() is called with -5 seconds |
| W-AUD-VIEW-10 | audio_player_view.dart | AudioPlayerView | seek forward when Right Arrow is pressed | Mock Player | Press Right Arrow | verify Player.seek() is called with +5 seconds |
| W-AUD-VIEW-11 | audio_player_view.dart | AudioPlayerView | volume up when Up Arrow is pressed | Mock Player volume=50 | Press Up Arrow | verify Player.setVolume(55) is called |
| W-AUD-VIEW-12 | audio_player_view.dart | AudioPlayerView | volume down when Down Arrow is pressed | Mock Player volume=50 | Press Down Arrow | verify Player.setVolume(45) is called |
| W-AUD-VIEW-13 | audio_player_view.dart | AudioPlayerView | toggle mute when M is pressed | Mock Player volume=50 | Press M | verify Player.setVolume(0) is called |
| W-AUD-VIEW-14 | audio_player_view.dart | AudioPlayerView | ignore keyboard shortcuts if text field is focused | Focus a text field in view | Press Space | verify Player.playOrPause() is NOT called |
| W-AUD-VIEW-15 | audio_player_view.dart | AudioPlayerView | delete selected file to trash | Select a file, mock directory repository | Press Delete | verify moveToTrash is called, queue updated |
| W-AUD-VIEW-16 | audio_player_view.dart | AudioPlayerView | permanently delete file | Select a file, mock directory repository | Press Shift+Delete | verify permanent delete dialog shows, deleteItem called |
| W-AUD-VIEW-17 | audio_player_view.dart | AudioPlayerView | skip delete confirmation if session dont ask again is true | Set _sessionDontAskTrash=true | Press Delete | verify dialog skipped, file deleted |
| W-AUD-VIEW-18 | audio_player_view.dart | AudioPlayerView | handle playing track deletion safely | Delete currently playing track | Confirm delete | verify Player.pause() called, queue updated, player opened with safe index |
| W-AUD-VIEW-19 | audio_player_view.dart | AudioPlayerView | navigate back in folder history | Mock folder history with 1 entry | Press Alt+Left Arrow | verify queue fetches previous folder, path history updated |
| W-AUD-VIEW-20 | audio_player_view.dart | AudioPlayerView | navigate forward in folder history | Mock forward history with 1 entry | Press Alt+Right Arrow | verify queue fetches next folder, history updated |
| W-AUD-VIEW-21 | audio_player_view.dart | AudioPlayerView | navigate up to parent directory | Mock currentPath nested | Press Alt+Up Arrow | verify queue fetches parent folder, history updated |
| W-AUD-VIEW-22 | audio_player_view.dart | AudioPlayerView | open rename/tag editor dialog on F2 | Select a file | Press F2 | verify AudioTagEditorDialog is shown |
| W-AUD-VIEW-23 | audio_player_view.dart | AudioPlayerView | handle rename callback from tag editor | Call onRename with new path | Provide oldPath and newPath | verify queues updated, selection updated, media_kit playlist URI updated |
| W-AUD-VIEW-24 | audio_player_view.dart | AudioPlayerView | open properties dialog on Alt+Enter | Select a file | Press Alt+Enter | verify AudioPropertiesDialog is shown |
| W-AUD-VIEW-25 | audio_player_view.dart | AudioPlayerView | display correct top bar metadata | Mock bitrate, size, queue position | Render view | Finds "Size • Bitrate • Index / Total" in top bar |
| W-AUD-VIEW-26 | audio_player_view.dart | AudioPlayerView | open settings dialog from top bar | Render view | Tap Settings Icon | verify SettingsDialog is shown focused on Audio tab |
