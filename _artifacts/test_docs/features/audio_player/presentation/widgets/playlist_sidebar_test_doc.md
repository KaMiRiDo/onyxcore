# Playlist Sidebar Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-SIDE-01 | playlist_sidebar.dart | PlaylistSidebar | display "No audio files found" when Home queue is empty | Mock empty audioQueueProvider, viewMode=home | Render widget | Finds "No audio files found" text |
| W-AUD-SIDE-02 | playlist_sidebar.dart | PlaylistSidebar | display "No favorite files in this folder" when Favorites queue is empty | Mock empty filteredQueue, viewMode=favorites | Render widget | Finds "No favorite files in this folder" text |
| W-AUD-SIDE-03 | playlist_sidebar.dart | PlaylistSidebar | update queue when directory watcher emits change | Mock directory repository watcher | Emit FileChangeEvent (create/delete/modify) | verify repo cache invalidated and queue refreshed |
| W-AUD-SIDE-04 | playlist_sidebar.dart | PlaylistSidebar | handle single click to select one item | Render list with 3 files | Tap file index 1 | verify audioSelectionProvider contains only file 1 |
| W-AUD-SIDE-05 | playlist_sidebar.dart | PlaylistSidebar | handle Ctrl+Click to add item to selection | Render list with 3 files | Ctrl+Tap file 1, then Ctrl+Tap file 2 | verify audioSelectionProvider contains both files 1 and 2 |
| W-AUD-SIDE-06 | playlist_sidebar.dart | PlaylistSidebar | handle Ctrl+Click to deselect an already selected item | Render list with 3 files, select file 1 and 2 | Ctrl+Tap file 1 | verify audioSelectionProvider contains only file 2 |
| W-AUD-SIDE-07 | playlist_sidebar.dart | PlaylistSidebar | handle Shift+Click range selection | Render list with 5 files | Tap file 1 (sets anchor), Shift+Tap file 3 | verify audioSelectionProvider contains files 1, 2, 3 |
| W-AUD-SIDE-08 | playlist_sidebar.dart | PlaylistSidebar | handle Shift+Click range selection upward | Render list with 5 files | Tap file 3 (sets anchor), Shift+Tap file 1 | verify audioSelectionProvider contains files 1, 2, 3 |
| W-AUD-SIDE-09 | playlist_sidebar.dart | PlaylistSidebar | update range anchor on single click | Render list with 5 files | Tap file 2 | verify audioSelectionAnchorProvider is set to index 2 |
| W-AUD-SIDE-10 | playlist_sidebar.dart | PlaylistSidebar | double click folder to navigate in | Render list with a folder | Double-tap folder | verify audioCurrentPathProvider updates to folder path, path history pushed, new queue loaded |
| W-AUD-SIDE-11 | playlist_sidebar.dart | PlaylistSidebar | push forward history to empty on folder navigation | Have existing forward history | Double-tap folder | verify audioPathForwardHistoryProvider is cleared |
| W-AUD-SIDE-12 | playlist_sidebar.dart | PlaylistSidebar | double click file to play from new playlist | Render list with audio files in folder B (not currently playing folder) | Double-tap file at index 2 | verify audioPlayingQueueProvider updated with folder B's queue, player.open() called at index 2 |
| W-AUD-SIDE-13 | playlist_sidebar.dart | PlaylistSidebar | double click file to jump when already in same playing folder | Render list in same folder as audioPlayingQueue | Double-tap file at index 1 | verify player.jump(1) called, audioPlayingQueue NOT replaced |
| W-AUD-SIDE-14 | playlist_sidebar.dart | PlaylistSidebar | display breadcrumbs correctly for nested path | Mock currentPath='/home/user/Music/Album', rootPath='/home/user' | Render widget | Finds breadcrumb segments 'Music', 'Album' with folder icon and '/' separators |
| W-AUD-SIDE-15 | playlist_sidebar.dart | PlaylistSidebar | navigate to folder on breadcrumb segment tap | Mock currentPath='/home/user/Music/Album' | Tap 'Music' breadcrumb | verify audioCurrentPathProvider updates to '/home/user/Music' |
| W-AUD-SIDE-16 | playlist_sidebar.dart | PlaylistSidebar | auto-scroll breadcrumbs to end on folder change | Navigate to deeply nested folder | After folder change animation | verify ScrollController animated to maxScrollExtent with 300ms easeOut |
| W-AUD-SIDE-17 | playlist_sidebar.dart | PlaylistSidebar | show context menu on right click | Render list with files | Secondary tap on file | verify ContextMenu is displayed with "Move to Trash", "Edit Tags", "Properties" items |
| W-AUD-SIDE-18 | playlist_sidebar.dart | PlaylistSidebar | show "Edit Tags" in context menu (not "Properties") when multiple selected | Select 2 files | Right-click on selection | verify context menu shows "Edit Tags" but NOT "Properties" |
| W-AUD-SIDE-19 | playlist_sidebar.dart | PlaylistSidebar | show "Properties" in context menu only for single selection | Select 1 file | Right-click on file | verify context menu shows "Properties" |
| W-AUD-SIDE-20 | playlist_sidebar.dart | PlaylistSidebar | toggle view mode between Home and Favorites | Render bottom navigation bar | Tap Favorites tab | verify audioViewModeProvider is set to AudioViewMode.favorites |
| W-AUD-SIDE-21 | playlist_sidebar.dart | PlaylistSidebar | toggle back to Home from Favorites | Set viewMode=favorites | Tap Home tab | verify audioViewModeProvider is set to AudioViewMode.home |
| W-AUD-SIDE-22 | playlist_sidebar.dart | PlaylistSidebar | render bottom nav bar with pill-shaped active indicator | Render widget, viewMode=home | Mount widget | verify active tab has Container with magenta 15% opacity, borderRadius=20 |
| W-AUD-SIDE-23 | playlist_sidebar.dart | PlaylistSidebar | render bottom nav bar with gradient icon for active tab | Render widget, viewMode=home | Mount widget | verify active tab icon uses ShaderMask with magenta→violet gradient |
| W-AUD-SIDE-24 | playlist_sidebar.dart | _TrackTile | display currently playing track with PlayingEqAnimation | Mock currentTrackProvider to match tile item, player playing | Render tile | Finds PlayingEqAnimation widget |
| W-AUD-SIDE-25 | playlist_sidebar.dart | _TrackTile | display paused indicator when track is active but paused | Mock currentTrack matching tile, player paused | Render tile | Finds Icons.pause_rounded with AppColors.magenta |
| W-AUD-SIDE-26 | playlist_sidebar.dart | _TrackTile | display 44x44 album art thumbnail from ID3 tags | Mock audioTagsProvider returning tag with picture | Render tile | Finds Image.memory widget inside 44x44 Container |
| W-AUD-SIDE-27 | playlist_sidebar.dart | _TrackTile | display gradient music note icon fallback when no album art | Mock audioTagsProvider returning tag without pictures | Render tile | Finds Icons.music_note_rounded with ShaderMask |
| W-AUD-SIDE-28 | playlist_sidebar.dart | _TrackTile | display artist and file size in subtitle | Mock audioTagsProvider with trackArtist="Artist" and file size=3200000 | Render tile | Finds subtitle containing "Artist" and "3.1 MB" |
| W-AUD-SIDE-29 | playlist_sidebar.dart | _TrackTile | display "Audio File" and size when no artist | Mock audioTagsProvider with null trackArtist | Render tile | Finds subtitle containing "Audio File" |
| W-AUD-SIDE-30 | playlist_sidebar.dart | _TrackTile | apply selected item styling | Set item as selected in audioSelectionProvider | Render tile | verify 10% white background, 15% white border applied |
| W-AUD-SIDE-31 | playlist_sidebar.dart | _TrackTile | apply active (playing) item styling | Set item as currently playing | Render tile | verify 3% white background, 5% white border applied |
| W-AUD-SIDE-32 | playlist_sidebar.dart | PlaylistSidebar | display folder tiles with audio file count | Mock folder with itemCount=5 | Render tile | Finds subtitle text containing "5" |
| W-AUD-SIDE-33 | playlist_sidebar.dart | PlaylistSidebar | display folder tiles with gradient folder icon | Render folder tile | Mount widget | Finds folder icon with ShaderMask gradient |
| W-AUD-SIDE-34 | playlist_sidebar.dart | PlaylistSidebar | render header title "Home" for home view mode | Set viewMode=home | Render widget | Finds Text "Home" with 18px bold style |
| W-AUD-SIDE-35 | playlist_sidebar.dart | PlaylistSidebar | render header title "Favorites" for favorites view mode | Set viewMode=favorites | Render widget | Finds Text "Favorites" |
| W-AUD-SIDE-36 | playlist_sidebar.dart | PlaylistSidebar | update search query on text input | Render widget with search bar | Enter "song" in search TextField | verify audioSearchQueryProvider is "song" |
| W-AUD-SIDE-37 | playlist_sidebar.dart | PlaylistSidebar | show sort overlay and update sort option | Render widget | Tap sort icon button | verify SortOverlay shows, select option updates audioSortOptionProvider |
| W-AUD-SIDE-38 | playlist_sidebar.dart | PlaylistSidebar | toggle hidden files from breadcrumb eye icon | Render widget, audioShowHidden=false | Tap visibility icon | verify audioShowHiddenProvider toggles to true, queue re-fetched |
| W-AUD-SIDE-39 | playlist_sidebar.dart | PlaylistSidebar | render hidden files icon with gradient when active | Set audioShowHidden=true | Render breadcrumb bar | verify eye icon uses ShaderMask gradient (magenta→violet) |
| W-AUD-SIDE-40 | playlist_sidebar.dart | PlaylistSidebar | render hidden files icon muted when inactive | Set audioShowHidden=false | Render breadcrumb bar | verify eye icon is muted color |
| W-AUD-SIDE-41 | playlist_sidebar.dart | PlaylistSidebar | trigger reload from breadcrumb refresh icon | Render widget | Tap reload icon | verify widget.onReload is called |
| W-AUD-SIDE-42 | playlist_sidebar.dart | PlaylistSidebar | clear selection when tapping empty background | Mock non-empty audioSelectionProvider | Tap empty space in sidebar ListView | verify audioSelectionProvider becomes empty set |
| W-AUD-SIDE-43 | playlist_sidebar.dart | PlaylistSidebar | show BubbleLoader when reloading | Mock audioIsReloadingProvider=true | Render widget | verify BubbleLoader is displayed with dimmed overlay (10% black) |
| W-AUD-SIDE-44 | playlist_sidebar.dart | PlaylistSidebar | hide BubbleLoader when not reloading | Mock audioIsReloadingProvider=false | Render widget | verify BubbleLoader is NOT visible |
| W-AUD-SIDE-45 | playlist_sidebar.dart | PlaylistSidebar | handle delete from context menu | Open context menu, select "Move to Trash" | Tap Move to Trash | verify widget.onDelete called with selected paths |
| W-AUD-SIDE-46 | playlist_sidebar.dart | PlaylistSidebar | handle edit tags from context menu | Open context menu on file | Tap Edit Tags | verify AudioTagEditorDialog.show is called with selected paths |
| W-AUD-SIDE-47 | playlist_sidebar.dart | PlaylistSidebar | handle properties from context menu on single file | Open context menu on single file | Tap Properties | verify AudioPropertiesDialog.show is called with file path |
| W-AUD-SIDE-48 | playlist_sidebar.dart | PlaylistSidebar | handle rename callback from context menu tag editor | Open tag editor from context menu, trigger onRename | Provide old and new paths | verify queue, selection, and current playing track path updated |
| W-AUD-SIDE-49 | playlist_sidebar.dart | PlaylistSidebar | highlight parent folder when active track is inside it | Mock currentPlayingTrack with path inside folder item | Render folder tile | verify folder tile shows PlayingEqAnimation (falls back to startsWith match) |
| W-AUD-SIDE-50 | playlist_sidebar.dart | PlaylistSidebar | render 36px height search bar | Render widget | Mount widget | verify search TextField container height is 36px |
| W-AUD-SIDE-51 | playlist_sidebar.dart | PlaylistSidebar | render bottom nav bar with top border separator | Render widget | Mount widget | verify bottom nav bar Container has top border (white 5-8% opacity) |
| W-AUD-SIDE-52 | playlist_sidebar.dart | PlaylistSidebar | dispose directory watcher subscription on unmount | Mount and unmount sidebar | Unmount widget | verify directory watcher stream subscription cancelled |
| W-AUD-SIDE-53 | playlist_sidebar.dart | PlaylistSidebar | auto-select right-clicked file if not already in selection | File at index 2 not in selection | Right-click file 2 | verify file 2 added to selection, then context menu shown |
| W-AUD-SIDE-54 | playlist_sidebar.dart | PlaylistSidebar | preserve existing multi-selection on right-click of selected item | Files 1, 2, 3 selected | Right-click file 2 | verify all 3 remain selected, context menu shown |
