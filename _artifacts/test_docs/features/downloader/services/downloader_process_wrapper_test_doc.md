# MediaDownloaderBackend Unit Test Plan

**File Under Test:** `lib/features/downloader/services/downloader_process_wrapper.dart`
**Target Layer:** Services
**Coverage Target:** >90%

## 1. `fetchMetadata` — Direct Delegation

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-01 | `downloader_process_wrapper.dart` | `fetchMetadata` | Delegate to the correct engine via `resolveEngine` | `engine = 'yt-dlp'` | Call `fetchMetadata` | Calls `fetchMetadata` on `YtDlpEngine` only |
| U-DL-BND-02 | `downloader_process_wrapper.dart` | `fetchMetadata` | Pass all parameters through | `url`, `browser`, `fetchDeep` provided | Call `fetchMetadata` | Engine receives all parameters |

## 2. `analyzeUrls` — URL Processing

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-03 | `downloader_process_wrapper.dart` | `analyzeUrls` | Skip empty/whitespace-only URLs | `urls = ['http://a', '', '  ', 'http://b']` | Call `analyzeUrls` | Only 2 URLs processed |
| U-DL-BND-04 | `downloader_process_wrapper.dart` | `analyzeUrls` | Trim whitespace from URLs | `urls = ['  http://a  ']` | Call `analyzeUrls` | Engine receives `'http://a'` |

## 3. Fallback Iteration (The "Auto" Sequence)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-05 | `downloader_process_wrapper.dart` | `analyzeUrls` | Transparent fallback on first engine failure | `auto` sequence resolves to `[Playwright, YtDlp]`, Playwright throws | Call `analyzeUrls` | Returns successful results from `YtDlpEngine` without crashing |
| U-DL-BND-06 | `downloader_process_wrapper.dart` | `analyzeUrls` | **[EDGE]** Fallback exhaustion — all engines fail | `auto` sequence of 3 engines, ALL throw Exceptions | Call `analyzeUrls` | Returns `MediaInfo` with `isError=true`, error message aggregates logs from all engines |
| U-DL-BND-07 | `downloader_process_wrapper.dart` | `analyzeUrls` | **[EDGE]** All engines fail with empty error map | `auto` sequence of 0 engines (none installed) | Call `analyzeUrls` | Returns `MediaInfo` with `isError=true`, error message is `'All available engines failed to analyze this URL.'` |

## 4. `PartialMetadataException` Handling

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-08 | `downloader_process_wrapper.dart` | `analyzeUrls` | Stop fallback when `PartialMetadataException` has non-empty `partialInfos` | Engine 1 throws `PartialMetadataException` with 5 items | Call `analyzeUrls` | Does NOT fallback, returns the 5 items immediately |
| U-DL-BND-09 | `downloader_process_wrapper.dart` | `analyzeUrls` | Continue fallback when `PartialMetadataException` has empty `partialInfos` | Engine 1 throws `PartialMetadataException` with 0 items | Call `analyzeUrls` | Continues to next engine in sequence |
| U-DL-BND-10 | `downloader_process_wrapper.dart` | `analyzeUrls` | Capture error message from PartialMetadataException | Engine throws with `message: 'Timed out'` | Call `analyzeUrls` | `errorMessage` on successful items contains `'Timed out'` |

## 5. Engine ID Injection

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-11 | `downloader_process_wrapper.dart` | `analyzeUrls` | Inject `engineId` into results when missing | Engine returns items with `engineId = null` | Call `analyzeUrls` | All returned `MediaInfo` items have `engineId` set to successful engine ID |
| U-DL-BND-12 | `downloader_process_wrapper.dart` | `analyzeUrls` | Preserve existing `engineId` on results | Engine returns items with `engineId = 'gallery-dl'` | Call `analyzeUrls` | Returned items keep their original `engineId` |
| U-DL-BND-13 | `downloader_process_wrapper.dart` | `analyzeUrls` | Inject engine ID into `onProgress` callback | Mock `Engine` calling `onProgress` | Call `analyzeUrls` with `onProgress` | Callback receives `MediaInfo` with populated `engineId` |

## 6. Pipeline Log Formatting

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-14 | `downloader_process_wrapper.dart` | `analyzeUrls` | Format logs with `======` separator between engine errors | Sequence: `[FailEngine, SuccessEngine]` | Call `analyzeUrls` | `fetchLogs` contains `[FailEngine]:\n<error>\n======\n[SuccessEngine]:\n<success logs>` |
| U-DL-BND-15 | `downloader_process_wrapper.dart` | `analyzeUrls` | Format logs for all-failed scenario | All 3 engines fail | Call `analyzeUrls` | `fetchLogs` contains all 3 engine error blocks separated by `======` |
| U-DL-BND-16 | `downloader_process_wrapper.dart` | `analyzeUrls` | Prefix `onProgress` callback fetchLogs with engine ID | Engine calls `onProgress` with `fetchLogs = 'some log'` | Handle callback | `fetchLogs` is `'[engine-id]:\nsome log'` |

## 7. `startDownload` — Parameter Pass-through

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-17 | `downloader_process_wrapper.dart` | `startDownload` | Route download to engine resolved from URL and preference | `engine = 'gallery-dl'` | Call `startDownload` | Calls `startDownload` on `GalleryDlEngine` |
| U-DL-BND-18 | `downloader_process_wrapper.dart` | `startDownload` | Pass through all 14 parameters to engine | All params provided | Call `startDownload` | Engine receives `url`, `destination`, `title`, `format`, `audioOnly`, `mute`, `galleryIndex`, `isPlaylist`, `isProfile`, `browser`, `isZip`, `filterType`, `totalItems`, `singleItemId`, `directUrl` |
| U-DL-BND-19 | `downloader_process_wrapper.dart` | `startDownload` | **[EDGE]** Handle missing engine ID fallback | `engine = 'auto'` with no URL pattern match | Call `startDownload` | Falls back to yt-dlp via `resolveEngine` |
