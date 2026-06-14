# DownloadTaskTile Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/widgets/download_task_tile.dart`
**Target Layer:** Presentation / UI
**Coverage Target:** >90%

## 1. UI Rendering based on Status

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-TIL-01 | `download_task_tile.dart` | `DownloadTaskTile` | Render Pending state correctly | Task status = `pending`, progress = 0 | Render Widget | Shows "Pending" badge, linear progress bar is animated, subtext "Waiting to start..." |
| W-DL-TIL-02 | `download_task_tile.dart` | `DownloadTaskTile` | Render Running state with metrics | Task status = `running`, speed='1 MB/s', ETA='10s', progress=0.5 | Render Widget | Shows "Running" badge, progress bar at 50%, TextSpan contains speed and ETA |
| W-DL-TIL-03 | `download_task_tile.dart` | `DownloadTaskTile` | Render Completed state | Task status = `completed` | Render Widget | Shows green "Completed" badge, subtext "Download finished successfully", progress bar hidden |
| W-DL-TIL-04 | `download_task_tile.dart` | `DownloadTaskTile` | Render Error state | Task status = `error`, error="Connection reset" | Render Widget | Shows red "Error" badge, text shows "Failed to download" and error message |
| W-DL-TIL-05 | `download_task_tile.dart` | `DownloadTaskTile` | Render Cancelled state | Task status = `cancelled` | Render Widget | Shows orange/grey "Cancelled" badge, progress bar hidden |
| W-DL-TIL-06 | `download_task_tile.dart` | `DownloadTaskTile` | Render Cancelling state | Task status = `cancelling` | Render Widget | Shows spinner, text indicates stopping process |

## 2. Dynamic Progress Logic & Display

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-TIL-07 | `download_task_tile.dart` | `_buildStatsSpans` | Format Playlist Item Counters | `totalItems=10`, `completedItems=3` | Check Stats Output | Displays "3/10" in the text block |
| W-DL-TIL-08 | `download_task_tile.dart` | `_computeEta` | Estimate Global ETA for Playlists | Playlist task running for 60 seconds, 50% complete | Evaluate `_computeEta` | Returns ~"1m 00s" |
| W-DL-TIL-09 | `download_task_tile.dart` | `DownloadTaskTile` | Live stream tile stats | Task `downloadType='live'`, speed='500 KB/s', totalSize='15 MB' | Render Widget | Shows recording duration/size instead of ETA |
| W-DL-TIL-10 | `download_task_tile.dart` | `DownloadTaskTile` | Thumbnail display | Task has associated thumbnail URL | Render Widget | Renders `CachedNetworkImage` with thumbnail |
| W-DL-TIL-11 | `download_task_tile.dart` | `DownloadTaskTile` | **[EDGE]** Very long title truncation | Task `title` is 200 characters long | Render Widget | Title is truncated with ellipsis, layout does not overflow |

## 3. User Interactions

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-TIL-12 | `download_task_tile.dart` | `DownloadTaskTile` | Trigger Cancel Confirmation | Task is `running` | Tap Cancel (X) icon | Overlay `_showCancelConfirm` appears |
| W-DL-TIL-13 | `download_task_tile.dart` | `_buildCancelConfirmation` | Cancel task and dismiss overlay | Overlay active | Tap "Yes, Cancel" | Calls `cancelDownload(id)`, overlay disappears |
| W-DL-TIL-14 | `download_task_tile.dart` | `DownloadTaskTile` | Remove completed task from UI | Task is `completed` | Tap Trash icon | Calls `removeTask(id)` on provider |
