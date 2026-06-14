# DownloadsPanelProvider Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/providers/downloads_panel_provider.dart`
**Target Layer:** Presentation / Providers
**Coverage Target:** 100%

## 1. Simple State Providers

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PNL-01 | `downloads_panel_provider.dart` | `downloadsPanelOpenProvider` | Default to false | - | Watch provider | State is `false` |
| U-DL-PNL-02 | `downloads_panel_provider.dart` | `downloadsPanelViewProvider` | Default to tasks | - | Watch provider | State is `DownloadsPanelView.tasks` |
| U-DL-PNL-03 | `downloads_panel_provider.dart` | `selectedDownloadHistoryIdProvider` | Default to null | - | Watch provider | State is `null` |
| U-DL-PNL-04 | `downloads_panel_provider.dart` | `isDownloadInputFocusedProvider` | Default to false | - | Watch provider | State is `false` |
| U-DL-PNL-05 | `downloads_panel_provider.dart` | `isDownloadsPanelFocusedProvider` | Default to false | - | Watch provider | State is `false` |
| U-DL-PNL-06 | `downloads_panel_provider.dart` | `downloadUrlFocusRequestProvider` | Default to 0 | - | Watch provider | State is `0` |
| U-DL-PNL-07 | `downloads_panel_provider.dart` | `isDownloadsPanelDraggingProvider` | Default to false | - | Watch provider | State is `false` |

## 2. DownloadsPanelView Enum

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PNL-08 | `downloads_panel_provider.dart` | `DownloadsPanelView` | Contain exactly 3 values | - | Check `DownloadsPanelView.values` | Contains `tasks`, `history`, `historyDetail` |

## 3. DownloadsPanelWidthNotifier

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PNL-09 | `downloads_panel_provider.dart` | `DownloadsPanelWidthNotifier.build` | Load width from Hive box | Mock Hive box containing `side_panel_width_pixels` = `400.0` | Initialize provider | State is `400.0` |
| U-DL-PNL-10 | `downloads_panel_provider.dart` | `DownloadsPanelWidthNotifier.build` | Default to 320.0 if Hive key missing | Mock Hive box without key | Initialize provider | State is `320.0` |
| U-DL-PNL-11 | `downloads_panel_provider.dart` | `DownloadsPanelWidthNotifier.updateWidth` | Update state and persist to Hive | Mock Hive box | Call `updateWidth(500.0)` | State is `500.0`, value persisted to Hive |

## 4. DownloadsListCache

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PNL-12 | `downloads_panel_provider.dart` | `DownloadsListCache()` | Initialize with empty/null fields | - | Create `DownloadsListCache()` | `parsedItems=null`, `configs={}`, `importedListName=null`, `importedListPath=null`, `isListChanged=false` |
| U-DL-PNL-13 | `downloads_panel_provider.dart` | `DownloadsListCache.clear` | Reset all fields to initial state | Cache with data | Call `clear()` | `parsedItems=null`, `configs={}`, `importedListName=null`, `importedListPath=null`, `isListChanged=false` |
