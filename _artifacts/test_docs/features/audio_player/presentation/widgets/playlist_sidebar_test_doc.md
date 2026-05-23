# Playlist Sidebar Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-SIDE-01 | playlist_sidebar.dart | PlaylistSidebar | display empty state when queue is empty | Mock empty audioQueueProvider | Render widget | Finds "No audio files found" text |
| W-AUD-SIDE-02 | playlist_sidebar.dart | PlaylistSidebar | update queue when directory watcher emits change | Mock directory repository watcher | Emit FileChangeEvent | verify repo cache invalidated and queue refreshed |
| W-AUD-SIDE-03 | playlist_sidebar.dart | PlaylistSidebar | handle single click selection | Render list with 3 files | Tap file index 1 | verify audioSelectionProvider contains only file 1 |
| W-AUD-SIDE-04 | playlist_sidebar.dart | PlaylistSidebar | handle Ctrl+click multi-selection | Render list with 3 files | Ctrl+Tap file 1, then Ctrl+Tap file 2 | verify audioSelectionProvider contains both files |
| W-AUD-SIDE-05 | playlist_sidebar.dart | PlaylistSidebar | handle Shift+click range selection | Render list with 5 files | Tap file 1, Shift+Tap file 3 | verify audioSelectionProvider contains files 1, 2, 3 |
| W-AUD-SIDE-06 | playlist_sidebar.dart | PlaylistSidebar | double click folder to navigate in | Render list with a folder | Double click folder | verify audioCurrentPathProvider updates, new queue loaded |
| W-AUD-SIDE-07 | playlist_sidebar.dart | PlaylistSidebar | double click file to play | Render list with audio file | Double click file | verify player.jump or player.open called with correct index/playlist |
| W-AUD-SIDE-08 | playlist_sidebar.dart | PlaylistSidebar | display breadcrumbs correctly | Mock currentPath = '/home/user/Music' | Render widget | Finds breadcrumb segments 'home', 'user', 'Music' |
| W-AUD-SIDE-09 | playlist_sidebar.dart | PlaylistSidebar | show context menu on right click | Render list with files | Secondary tap on file | verify ContextMenu is displayed with Edit Tags/Properties |
| W-AUD-SIDE-10 | playlist_sidebar.dart | PlaylistSidebar | toggle view mode between Home and Favorites | Render bottom navigation bar | Tap Favorites tab | verify audioViewModeProvider is set to favorites |
| W-AUD-SIDE-11 | playlist_sidebar.dart | _TrackTile | display currently playing track visual indicator | Mock currentTrackProvider to match tile item | Render tile | verify isActive is true, visual styles applied |
| W-AUD-SIDE-12 | playlist_sidebar.dart | PlaylistSidebar | update search query on text input | Render widget with search bar | Enter "song" in search bar | verify audioSearchQueryProvider is "song" |
| W-AUD-SIDE-13 | playlist_sidebar.dart | PlaylistSidebar | show sort overlay and update sort option | Render widget | Tap sort icon | verify SortOverlay shows, select option updates audioSortOptionProvider |
| W-AUD-SIDE-14 | playlist_sidebar.dart | PlaylistSidebar | toggle hidden files from breadcrumbs | Render widget | Tap visibility icon in breadcrumbs | verify audioShowHiddenProvider toggles and queue re-fetched |
| W-AUD-SIDE-15 | playlist_sidebar.dart | PlaylistSidebar | trigger reload from breadcrumbs | Render widget | Tap reload icon in breadcrumbs | verify widget.onReload is called |
| W-AUD-SIDE-16 | playlist_sidebar.dart | PlaylistSidebar | clear selection when tapping background | Mock non-empty selection | Tap empty space in sidebar | verify audioSelectionProvider becomes empty |
| W-AUD-SIDE-17 | playlist_sidebar.dart | PlaylistSidebar | show loading indicator when reloading | Mock audioIsReloadingProvider=true | Render widget | verify BubbleLoader is displayed |
| W-AUD-SIDE-18 | playlist_sidebar.dart | PlaylistSidebar | handle delete from context menu | Open context menu | Tap Move to Trash | verify widget.onDelete or repo.moveToTrash called |
| W-AUD-SIDE-19 | playlist_sidebar.dart | PlaylistSidebar | handle edit tags from context menu | Open context menu | Tap Edit Tags | verify AudioTagEditorDialog is shown |
| W-AUD-SIDE-20 | playlist_sidebar.dart | PlaylistSidebar | handle properties from context menu | Open context menu on single file | Tap Properties | verify AudioPropertiesDialog is shown |
| W-AUD-SIDE-21 | playlist_sidebar.dart | PlaylistSidebar | handle rename callback in context menu | Trigger onRename callback from Edit Tags | Provide old and new paths | verify queue, selection, and current playing track reflect new path |
