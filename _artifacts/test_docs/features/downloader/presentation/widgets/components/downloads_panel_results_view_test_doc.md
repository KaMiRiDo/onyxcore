# Downloads Panel Results View Test Plan

**File Under Test:** `lib/features/downloader/presentation/widgets/components/downloads_panel_results_view.dart`
**Target Layer:** Presentation / Widgets
**Coverage Target:** >90%

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-RSV-01 | `downloads_panel_results_view.dart` | `_filteredItems` | return empty list when there are no parsed items | `_parsedItems=null` | build results view | no rows render and empty state appears |
| W-DL-RSV-02 | `downloads_panel_results_view.dart` | `_filteredItems` | filter image-only entries correctly | mixed parsed groups including profile/playlist/video/image | set `_sortFilter='image'` | only non-video, non-playlist, non-profile groups remain |
| W-DL-RSV-03 | `downloads_panel_results_view.dart` | `_filteredItems` | filter videos, playlists, and profiles with the documented branches | same mixed dataset | set sort filter to `video`, `playlist`, and `profile` | each filter exposes only the expected group types |
| W-DL-RSV-04 | `downloads_panel_results_view.dart` | `_filteredItems` sorting | sort by added asc/desc and by computed size asc/desc | parsed items with different insertion order and config-derived sizes | change sort filter | order changes according to selected comparator |
| W-DL-RSV-05 | `downloads_panel_results_view.dart` | `_filteredItems` cache | reuse cached filtered results until invalidated by panel state changes | initial filtered list built once | rebuild without changing inputs | cached list is reused and visible ordering stays stable |
| W-DL-RSV-06 | `downloads_panel_results_view.dart` | header title | show imported list name with tooltip fallback to `Fetched Media` | imported and non-imported states | pump view | title text and tooltip match active source |
| W-DL-RSV-07 | `downloads_panel_results_view.dart` | imported-list close chip | route imported-list close through unsaved-change guard | imported dirty list present | tap close icon | dirty list opens unsaved confirmation; clean list clears items/configs/import metadata immediately |
| W-DL-RSV-08 | `downloads_panel_results_view.dart` | filter dropdown | disable filter control when no items exist | empty and non-empty states | inspect and tap dropdown | disabled state uses reduced opacity; enabled state opens all sort options |
| W-DL-RSV-09 | `downloads_panel_results_view.dart` | active sort pill | highlight non-default sort and allow quick reset to `added_desc` | sort set to `size_desc` or `image` | tap clear icon inside pill | `_sortFilter` resets to default |
| W-DL-RSV-10 | `downloads_panel_results_view.dart` | clear button | remove only selected groups when selection exists | loaded list with selected indices | tap `Clear N` | selected rows are removed |
| W-DL-RSV-11 | `downloads_panel_results_view.dart` | clear button fallback | clear whole list when nothing is selected | loaded list with no selection | tap `Clear` | parsed items, configs, preview, and selection are cleared through guarded path |
| W-DL-RSV-12 | `downloads_panel_results_view.dart` | statistics strip | render total size, image count, video count, and current-folder toggle from live state | parsed items and settings provider values present | pump view and toggle switch | counts match recalculated stats and `setDownloadToCurrentFolder` is called |
| W-DL-RSV-13 | `downloads_panel_results_view.dart` | underestimated-size marker | prefix total size with `~` when list contains playlist/profile groups | `_hasUnderestimatedSize=true` | pump view | total size text starts with `~ ` |
| W-DL-RSV-14 | `downloads_panel_results_view.dart` | drag target highlight | show import overlay messaging for empty vs conflicting states | empty panel and already-populated panel variants | drag file over target | overlay says `Drop JSON list to import` or conflict warning accordingly |
| W-DL-RSV-15 | `downloads_panel_results_view.dart` | drag target accept | import dropped JSON files only when the panel is empty | drop `.json` path onto empty state | accept drop | `_importList(path)` runs |
| W-DL-RSV-16 | `downloads_panel_results_view.dart` | drag target reject | show toast for non-JSON drops or when list already contains data | populated panel or non-JSON path | drop file | correct toast is shown and no import occurs |
| W-DL-RSV-17 | `downloads_panel_results_view.dart` | list area | render `DownloadsEmptyState` when display list is empty | no filtered items | pump view | empty-state widget is visible |
| W-DL-RSV-18 | `downloads_panel_results_view.dart` | list area rows | build media tiles using stable keys for each filtered entry | parsed groups present | pump and scroll list | one keyed tile renders per filtered group |
| W-DL-RSV-19 | `downloads_panel_results_view.dart` | bottom export/update button | switch between `Export` and `Update` modes based on imported path and dirty state | imported clean, imported dirty, and non-imported list variants | inspect and tap button | correct label/icon/disabled state appear and correct callback runs |
| W-DL-RSV-20 | `downloads_panel_results_view.dart` | import button | disable import while parsed items already exist | empty and non-empty panels | inspect button | button opacity and pointer behavior match availability |
| W-DL-RSV-21 | `downloads_panel_results_view.dart` | download-all button | show `Download All` or `Download N` and disable when there are no items | empty list, full list, selection variant | inspect and tap button | label matches selection state and `_startDownloadAll` runs only when enabled |
| W-DL-RSV-22 | `downloads_panel_results_view.dart` | active-download summary | compute average progress across active tasks and show indeterminate bar when progress is zero | active tasks provider with zero/non-zero progress | pump view | summary text, arrow icon, and bar mode match task data |
| W-DL-RSV-23 | `downloads_panel_results_view.dart` | downloads drawer | expand/collapse active tasks list and render `DownloadTaskTile` entries | active tasks present | tap summary strip | drawer animates open and task tiles render |
| W-DL-RSV-24 | `downloads_panel_results_view.dart` | cancel-all confirmation | show modal, cancel it with `No`, or cancel every active task with `Yes` | drawer open and active tasks provider populated | tap `Cancel All`, then confirm/dismiss | confirmation overlay appears; `cancelDownload` is called once per active task only on `Yes` |

