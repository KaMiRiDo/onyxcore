# MediaDownloaderBackend Unit Test Plan

**File Under Test:** `lib/features/downloader/services/downloader_process_wrapper.dart`
**Target Layer:** Services
**Coverage Target:** >90%

## 1. Top-Level Facade Routing

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-01 | `downloader_process_wrapper.dart` | `analyzeUrls` | Delegate to the correct engine | `engine = 'yt-dlp'` | Call `analyzeUrls` | Calls `fetchMetadata` on `YtDlpEngine` only |
| U-DL-BND-02 | `downloader_process_wrapper.dart` | `analyzeUrls` | Remove duplicate URLs before passing to engine | `urls = ['http://a', 'http://a']` | Call `analyzeUrls` | Only 1 URL is processed |

## 2. Fallback Iteration (The "Auto" sequence)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-BND-03 | `downloader_process_wrapper.dart` | `analyzeUrls` | Transparent fallback on first engine failure | `auto` sequence resolves to `[Playwright, YtDlp]`, Playwright throws | Call `analyzeUrls` | Returns successful results from `YtDlpEngine` without crashing |
| U-DL-BND-04 | `downloader_process_wrapper.dart` | `analyzeUrls` | **[EDGE]** Fallback exhaustion | `auto` sequence of 3 engines, ALL throw Exceptions | Call `analyzeUrls` | Returns `MediaInfo` marking `isError=true`, error message aggregates logs from all 3 engines |
| U-DL-BND-05 | `downloader_process_wrapper.dart` | `analyzeUrls` | Ignore `PartialMetadataException` for fallbacks | Engine 1 throws `PartialMetadataException` with 5 items | Call `analyzeUrls` | Does NOT fallback, returns the 5 items immediately |
| U-DL-BND-06 | `downloader_process_wrapper.dart` | `startDownload` | Route download to engine assigned in `MediaInfo` | `media.engineId = 'gallery-dl'` | Call `startDownload` | Calls `startDownload` on `GalleryDlEngine` |
| U-DL-BND-07 | `downloader_process_wrapper.dart` | `startDownload` | **[EDGE]** Handle missing engine ID | `media.engineId = null` | Call `startDownload` | Resolves via `EngineRegistry` fallback matching |
| U-DL-BND-08 | `downloader_process_wrapper.dart` | `analyzeUrls` | Inject engine ID into onProgress callback | Mock `Engine` calling `onProgress` | Call `analyzeUrls` with `onProgress` | Callback receives `MediaInfo` with populated `engineId` |
| U-DL-BND-09 | `downloader_process_wrapper.dart` | `analyzeUrls` | Format logs correctly when fallback succeeds | Sequence: `[FailEngine, SuccessEngine]` | Call `analyzeUrls` | `fetchLogs` contains `[FailEngine]: <error> === [SuccessEngine]: <success logs>` |
