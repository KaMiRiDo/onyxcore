# Download History Widgets Unit Test Plan

**Files Under Test:** 
- `lib/features/downloader/presentation/widgets/download_history_view.dart`
- `lib/features/downloader/presentation/widgets/download_history_detail_view.dart`
**Target Layer:** Presentation / UI
**Coverage Target:** >80%

## 1. History List View

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-HIS-01 | `download_history_view.dart` | `DownloadHistoryView` | Render empty state | `filteredDownloadHistoryProvider` returns empty list | Render Widget | Shows "No History Found" message |
| W-DL-HIS-02 | `download_history_view.dart` | `DownloadHistoryView` | Trigger Pagination on Scroll | List has 50 items, `hasMore=true` | Scroll to bottom | Calls `loadMore()` on history provider |
| W-DL-HIS-03 | `download_history_view.dart` | `DownloadHistoryView` | Multi-select context menu | Select 2 items | Verify Header | Shows "2 Selected" and Delete Action button |

## 2. History Filters

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-HIS-04 | `download_history_view.dart` | `_buildFilters` | Render Status Dropdown | Render History Header | Tap Status Filter | Opens dropdown with 'All', 'Completed', 'Error', 'Cancelled' |
| W-DL-HIS-05 | `download_history_view.dart` | `_buildFilters` | Update Filter State | Select 'Error' | Verify State | `downloadHistoryFilterProvider` status updates to 'Error' |

## 3. History Detail View

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-HIS-06 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Display full metadata | Item selected in provider | Render Detail View | Shows URL, destination, completion time, status |
| W-DL-HIS-07 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Open destination folder | Valid destination string | Tap "Open Folder" | Calls `ProcessUtils.openFileBrowser` |
| W-DL-HIS-08 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Display Logs Terminal | Item has raw logs | Scroll down | Shows code block container with monospace logs |
