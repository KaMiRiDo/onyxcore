# Download History Widgets Unit Test Plan

**Files Under Test:** 
- `lib/features/downloader/presentation/widgets/download_history_view.dart`
- `lib/features/downloader/presentation/widgets/download_history_detail_view.dart`
**Target Layer:** Presentation / UI
**Coverage Target:** >90%

## 1. History List View (`download_history_view.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-HIS-01 | `download_history_view.dart` | `DownloadHistoryView` | Render empty state | `filteredDownloadHistoryProvider` returns empty list | Render Widget | Shows "No History Found" or similar empty state |
| W-DL-HIS-02 | `download_history_view.dart` | `DownloadHistoryView` | Trigger Pagination on Scroll | List has 50 items, `hasMore=true` | Scroll to bottom of `ListView` | Calls `loadMore()` on history provider |
| W-DL-HIS-03 | `download_history_view.dart` | `DownloadHistoryView` | Toggle multi-select context menu | Select 2 items via long press/checkbox | Verify Header | Header transitions to selection mode, shows "2 Selected" |
| W-DL-HIS-04 | `download_history_view.dart` | `DownloadHistoryView` | Keyboard navigation and selection | Focus node active on list | Press Shift+DownArrow | Triggers `selectRange` on `DownloadHistorySelectionNotifier` |
| W-DL-HIS-05 | `download_history_view.dart` | `DownloadHistoryView` | Clear All button | History populated | Tap "Clear All" in menu | Shows confirmation dialog, then calls `clearAll()` |
| W-DL-HIS-06 | `download_history_view.dart` | `DownloadHistoryView` | Delete Confirmation dialog | 1 item selected | Tap Delete icon | Shows dialog "Delete 1 item?". Tapping Confirm deletes it |
| W-DL-HIS-07 | `download_history_view.dart` | `DownloadHistoryView` | **[EDGE]** Empty selection prevents delete | Selection is empty | Attempt to tap Delete (if visible) | Action is disabled or no-op |

## 2. History Filters

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-HIS-08 | `download_history_view.dart` | `_buildFilters` | Render Status Dropdown | Render History Header | Tap Status Filter | Opens dropdown with 'All', 'Completed', 'Error', 'Cancelled' |
| W-DL-HIS-09 | `download_history_view.dart` | `_buildFilters` | Update Status Filter State | Select 'Error' | Verify State | `downloadHistoryFilterProvider` status updates to 'Error' |
| W-DL-HIS-10 | `download_history_view.dart` | `_buildFilters` | Date filter calendar UI | Tap Date Filter | Calendar pop-up appears | Allows selecting specific dates present in `availableDownloadDatesProvider` |

## 3. History Detail View (`download_history_detail_view.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-HIS-11 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Display full metadata | Item selected in provider | Render Detail View | Shows URL, destination, completion time, status |
| W-DL-HIS-12 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Open destination folder | Valid destination string | Tap "Open Folder" | Calls `ProcessUtils.openFileBrowser` |
| W-DL-HIS-13 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Copy URL to clipboard | Tap "Copy URL" | Verify Clipboard | Clipboard contains `item.url` |
| W-DL-HIS-14 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Re-download action | Item has valid URL/destination | Tap "Re-download" | Passes args back to input provider and switches to tasks view |
| W-DL-HIS-15 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Display duration | Item has start/end times | Render view | Duration text is visible (e.g. "5m 20s") |
| W-DL-HIS-16 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Display Logs Terminal | Item has non-empty logs list | Scroll down | Shows code block container rendering monospace logs |
| W-DL-HIS-17 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Hide Logs Terminal | Item has empty logs | Scroll down | Logs block is hidden |
| W-DL-HIS-18 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Render "History not found" | Entry ID exists but entry is null | Render view | Displays "History not found" fallback |
| W-DL-HIS-19 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Render Cancelled badge | Item status is cancelled | Render view | Displays orange Cancelled badge |
| W-DL-HIS-20 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Delete entry from details | Tap delete icon | Verify Providers | Deletes entry, sets ID to null, returns to history view |
| W-DL-HIS-21 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Close button to tasks view | Tap close icon | Verify Providers | Sets ID to null, switches view back to tasks |
| W-DL-HIS-22 | `download_history_detail_view.dart` | `DownloadHistoryDetailView` | Back button to history view | Tap back arrow | Verify Providers | Sets ID to null, switches view to history |
