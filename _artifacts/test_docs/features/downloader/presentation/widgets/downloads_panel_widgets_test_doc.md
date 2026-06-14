# Downloads Panel Widgets Unit Test Plan

**Files Under Test:** 
- `lib/features/downloader/presentation/widgets/downloads_panel.dart`
- `lib/features/downloader/presentation/widgets/components/downloads_panel_input.dart`
- `lib/features/downloader/presentation/widgets/components/downloads_panel_results_view.dart`
- `lib/features/downloader/presentation/widgets/components/downloads_panel_preview.dart`
- `lib/features/downloader/presentation/widgets/components/downloads_panel_controls.dart`
**Target Layer:** Presentation / UI
**Coverage Target:** >90%

## 1. Top-Level Panel & Navigation (`downloads_panel.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-01 | `downloads_panel.dart` | `DownloadsPanel` | Navigate based on `downloadsPanelViewProvider` | Render `DownloadsPanel` | Set view provider to `tasks` | Renders `_MediaDownloaderPanel` via IndexedStack |
| W-DL-PNL-02 | `downloads_panel.dart` | `DownloadsPanel` | Navigate to History View | Render `DownloadsPanel` | Set view provider to `history` | Renders `DownloadHistoryView` |
| W-DL-PNL-03 | `downloads_panel.dart` | `DownloadsPanel` | Handle keyboard shortcuts | Render Panel, Focus Node active | Press `Ctrl+B` | Toggles background panel provider state |

## 2. Input & URL Analysis (`downloads_panel_input.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-06 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Trigger URL analysis on Submit | Text input contains valid URL | Tap Analyze Button | Calls `MediaDownloaderBackend.analyzeUrls` with correct args |
| W-DL-PNL-07 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Prevent analysis without required binaries | Set `EngineRegistry.requiredInstalled = false` | Enter URL | Analyze button is disabled or shows Warning overlay |
| W-DL-PNL-08 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Batch analysis of multiple URLs | Paste multiple lines into input | Tap Analyze | Backend parses multi-line input correctly |
| W-DL-PNL-09 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Parse deep/shallow fetch flags | UI toggle set to "Deep Scan" | Tap Analyze | `fetchDeep=true` passed to backend |
| W-DL-PNL-10 | `downloads_panel_input.dart` | `_DownloadsPanelInput` | Extract and pass cookies | Input state contains browser selection | Tap Analyze | `CookieHelper` is called to extract cookies before analysis |

## 3. Results List View (`downloads_panel_results_view.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-11 | `downloads_panel_results_view.dart` | `_DownloadsPanelResultsView` | Render empty state | `_parsedItems` is empty | Render Widget | Displays `DownloadsEmptyState` illustration |
| W-DL-PNL-12 | `downloads_panel_results_view.dart` | `_DownloadsPanelResultsView` | Render item list | `_parsedItems` has 3 valid `MediaInfo` items | Render Widget | Shows 3 `MediaInfoListTile` widgets |
| W-DL-PNL-13 | `downloads_panel_results_view.dart` | `_DownloadsPanelResultsView` | Toggle item selection | Tap checkbox on item | Check state | Item added to `_selectedItems` set |
| W-DL-PNL-14 | `downloads_panel_results_view.dart` | `_DownloadsPanelResultsView` | Select All / Deselect All | Header checkbox tapped | Check state | All items added/removed from selection |
| W-DL-PNL-15 | `downloads_panel_results_view.dart` | `_importList` | Import JSON via file picker | Mock `FilePicker` returning valid JSON | Tap "Import" | State updates with `_parsedItems` from JSON |
| W-DL-PNL-16 | `downloads_panel_results_view.dart` | `_importList` | **[EDGE]** Import Corrupted JSON | User selects invalid JSON file | Call `_importList` | Catches `FormatException`, shows Toast "Invalid JSON file" |
| W-DL-PNL-17 | `downloads_panel_results_view.dart` | `_exportList` | Export items to JSON | `_parsedItems` populated | Tap "Export" | Serializes to JSON and writes to disk via `ProcessUtils` |

## 4. Item Preview & Config (`downloads_panel_preview.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-18 | `downloads_panel_preview.dart` | `_DownloadsPanelPreview` | Display selected item thumbnail | Single item selected | Render Preview | `CachedNetworkImage` displays thumbnail |
| W-DL-PNL-19 | `downloads_panel_preview.dart` | `_DownloadsPanelPreview` | Update Format Dropdown on config change | Preview state active | Select new resolution | Updates `DownloadConfig` for the group, redraws dropdown |
| W-DL-PNL-20 | `downloads_panel_preview.dart` | `_DownloadsPanelPreview` | Toggle Audio/Video mode | Segmented control switched to 'Audio Only' | Render Preview | Formats list updates to only show audio streams |
| W-DL-PNL-21 | `downloads_panel_preview.dart` | `_DownloadsPanelPreview` | Group state rendering | Multiple items selected | Render Preview | Shows "N items selected" summary instead of single item detail |

## 5. Controls & Download Triggering (`downloads_panel_controls.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-22 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Trigger `startDownload` on selected items | 2 items selected in UI | Tap "Download Selected" | Calls `downloadTaskProvider.startDownload` 2 times |
| W-DL-PNL-23 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Pass correct configs | Download triggered | Intercept call | Ensures selected formats and `DownloadConfig` match UI state |
| W-DL-PNL-24 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Request directory picker if download path missing | Download directory empty in settings | Tap "Download Selected" | Triggers `DirectoryPickerDialog` |
| W-DL-PNL-25 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Calculate combined size correctly | Selected items total 100MB | Render Widget | Button label shows "Download (100MB)" |
| W-DL-PNL-26 | `downloads_panel_controls.dart` | `_DownloadsPanelControls` | Disable button when no selection | `_selectedItems` empty | Render Widget | Download button is disabled |

## 6. Panel Tiles & Shared States (`downloads_panel_tiles.dart` & `downloads_empty_state.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PNL-27 | `downloads_panel_tiles.dart` | `_buildErrorTile` | Render error tile | Item has `isError = true` | Render Tile | Displays red error styling and error message |
| W-DL-PNL-28 | `downloads_panel_tiles.dart` | `_buildMediaTile` | Ctrl+Click selection | 2 items rendered | Ctrl+Click second item | Appends item to `_selectedIndices` |
| W-DL-PNL-29 | `downloads_panel_tiles.dart` | `_buildMediaTile` | Shift+Click selection | 5 items rendered | Shift+Click item 4 | Selects all items from anchor index to 4 |
| W-DL-PNL-30 | `downloads_panel_tiles.dart` | `_buildMediaTile` | Delete item from list | Tap 'X' button on tile | Verify list | Calls `_removeParsedItems` to remove it |
| W-DL-PNL-31 | `downloads_panel_tiles.dart` | `_buildMediaTile` | Action icon buttons | Tap Info/Copy URL | Verify overlays | Opens logs modal / Copies to clipboard |
| W-DL-PNL-32 | `downloads_empty_state.dart` | `DownloadsEmptyState` | Render empty state text | Render Empty State | Check UI | Displays "Paste a link..." instructions |
| W-DL-PNL-33 | `downloads_shared_components.dart` | `CountIndicator` | Render custom indicator | Pass icon and count | Check UI | Renders correctly formatted badge |
