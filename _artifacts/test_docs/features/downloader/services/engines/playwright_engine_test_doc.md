# PlaywrightEngine Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/playwright_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** >90%

## 1. Python Environment & Script Setup

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PLW-01 | `playwright_engine.dart` | `binaryPath` | Return Python executable | System `python3` exists | Check `binaryPath` | Returns `'python3'` (or `'python'` on Windows) |
| U-DL-PLW-02 | `playwright_engine.dart` | `_ensureDependencies` | Install `playwright` via PIP | Playwright package missing | Call `_ensureDependencies` | Runs `python -m pip install playwright` and `playwright install` |
| U-DL-PLW-03 | `playwright_engine.dart` | `_ensureDependencies` | **[EDGE]** Handle PIP timeout or permissions | PIP hangs or lacks root | Call `_ensureDependencies` | Catches timeout, throws user-friendly permission/network error |
| U-DL-PLW-04 | `playwright_engine.dart` | `_writeScript` | Generate transient python script | `appDataDir` is `/tmp/dir` | Call `fetchMetadata` | Writes `playwright_extractor.py` to temp directory |

## 2. Scraping & Metadata Fetching

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PLW-05 | `playwright_engine.dart` | `fetchMetadata` | Execute Python script to extract direct video URL | Mock Python stdout emitting `{"url": "...", "title": "..."}` | Call `fetchMetadata` | Returns `MediaInfo` with parsed JSON fields |
| U-DL-PLW-06 | `playwright_engine.dart` | `fetchMetadata` | Parse embedded HLS/M3U8 streams | Python output contains `.m3u8` URL | Call `fetchMetadata` | Format `protocol` is marked as `m3u8_native` |
| U-DL-PLW-07 | `playwright_engine.dart` | `fetchMetadata` | **[EDGE]** Bypass failure or CAPTCHA block | Python script hits hCaptcha and times out | Call `fetchMetadata` | Throws Exception mentioning bypass failure or bot detection |

## 3. Download Execution (Aria2/FFmpeg/Curl Handoff)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PLW-08 | `playwright_engine.dart` | `startDownload` | Use Aria2 for direct URLs extracted by Playwright | `Aria2Accelerator.isAvailable = true` | Call `startDownload` | Executes `aria2c` pointing to extracted `directUrl` |
| U-DL-PLW-09 | `playwright_engine.dart` | `startDownload` | **[EDGE]** Fallback to `ffmpeg` for HLS streams | `Aria2Accelerator` available but URL is `.m3u8` | Call `startDownload` | Executes `ffmpeg -i` instead of `aria2c` |
| U-DL-PLW-10 | `playwright_engine.dart` | `startDownload` | Fallback to curl if Aria2 absent | `formatString` contains `.mp4`, Aria2 is unavailable | Call `startDownload` | Executes `curl` with `-L` and `-o` |
