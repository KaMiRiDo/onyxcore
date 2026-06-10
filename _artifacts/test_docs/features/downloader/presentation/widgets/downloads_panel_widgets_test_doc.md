# Downloads Panel Widgets Unit Test Plan

**Files Under Test:** 
- `lib/features/downloader/presentation/widgets/downloads_panel.dart`
- `lib/features/downloader/presentation/widgets/components/*`
**Target Layer:** Presentation / UI
**Coverage Target:** >80%

## 1. Top-Level Panel & Navigation

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-01 | `downloads_panel.dart` | `DownloadsPanel` | Navigate based on `downloadsPanelViewProvider` | Render `DownloadsPanel` | Set view provider to `tasks` | Renders `_MediaDownloaderPanel` via IndexedStack |
| W-DL-PNL-02 | `downloads_panel.dart` | `DownloadsPanel` | Navigate to History View | Render `DownloadsPanel` | Set view provider to `history` | Renders `DownloadHistoryView` |
| W-DL-PNL-03 | `downloads_panel.dart` | `DownloadsPanel` | Handle keyboard shortcuts | Render Panel, Focus Node active | Press `Ctrl+B` | Toggles background panel provider state |
| W-DL-PNL-04 | `downloads_panel.dart` | `DownloadsPanel` | **[EDGE]** Keyboard Shortcut Collisions | Render Panel | Mash `Ctrl+D` and `Ctrl+\`` simultaneously | Only one state mutation occurs without crashing |
| W-DL-PNL-05 | `downloads_panel.dart` | `DownloadsPanel` | **[EDGE]** Scroll Controller Assertion | Render Panel | Trigger `_scrollToBottomLogs()` before layout completes | `hasClients` check prevents `ScrollController` crash |

## 2. Input & URL Analysis

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-06 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Trigger URL analysis on Submit | Text input contains valid URL | Tap Analyze Button | Calls `MediaDownloaderBackend.analyzeUrls` with correct args |
| W-DL-PNL-07 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Prevent analysis without required binaries | Set `EngineRegistry.requiredInstalled = false` | Enter URL | Analyze button is disabled or shows Warning overlay |

## 3. Results & Preview Views

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-08 | `downloads_panel_results_view.dart` | `_DownloadsPanelResultsView` | Render empty state | `_parsedItems` is empty | Render Widget | Displays `DownloadsEmptyState` |
| W-DL-PNL-09 | `downloads_panel.dart` | `_importList` | **[EDGE]** Import Corrupted JSON | User selects manually edited, invalid JSON | Call `_importList` | Catches FormatException, shows Toast "Invalid JSON file" |
| W-DL-PNL-10 | `downloads_panel_preview.dart` | `_DownloadsPanelPreview` | Update Format Dropdown on config change | Preview state active | Select new resolution in dropdown | Updates `DownloadConfig` for the group |

## 4. Controls & Download Triggering

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-11 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Trigger `startDownload` on selected items | 2 items selected in UI | Tap "Download Selected" | Calls `downloadTaskProvider.startDownload` 2 times |
| W-DL-PNL-12 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Request directory picker if download path missing | Download directory empty in settings | Tap "Download Selected" | Triggers `DirectoryPickerDialog` |
| W-DL-PNL-13 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Calculate combined size correctly | Selected items total 100MB | Render Widget | Button label shows "Download (100MB)" |
