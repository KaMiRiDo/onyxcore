# DownloadHistoryProvider Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/providers/download_history_provider.dart`
**Target Layer:** Presentation / Providers
**Coverage Target:** >90%

## 1. History Pagination & State

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-01 | `download_history_provider.dart` | `build` | Load initial page of results | Mock DB with 100 entries | Initialize Provider | State length is 50, `hasMore` is true |
| U-DL-HST-02 | `download_history_provider.dart` | `loadMore` | Load subsequent page | Provider initialized | Call `loadMore` | State length increases to 100 |
| U-DL-HST-03 | `download_history_provider.dart` | `addEntry` | Prepend new entry to state | Mock DB with 10 entries | Call `addEntry` | State length is 11, new entry is at index 0 |

## 2. Filtering & Selection

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-04 | `download_history_provider.dart` | `filteredDownloadHistoryProvider` | Filter history by exact date | State contains items from today and yesterday | Update `downloadHistoryFilterProvider` to yesterday | Provider outputs only yesterday's items |
| U-DL-HST-05 | `download_history_provider.dart` | `filteredDownloadHistoryProvider` | Filter history by status | State contains 'completed' and 'error' items | Update filter status to 'error' | Outputs only 'error' items |
| U-DL-HST-06 | `download_history_provider.dart` | `DownloadHistorySelectionNotifier` | Toggle item selection | Initial empty selection | Call `toggle('1')` | State contains '1'. Call `toggle('1')` again, state is empty |
| U-DL-HST-07 | `download_history_provider.dart` | `DownloadHistorySelectionNotifier` | Shift-click multi-select | List of IDs A, B, C, D. State contains 'A' | Call `selectRange(..., 'D')` | State contains A, B, C, D |
