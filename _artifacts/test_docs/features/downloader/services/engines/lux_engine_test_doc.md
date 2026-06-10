# LuxEngine Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/lux_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** >90%

## 1. Environment & Path Resolution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-LUX-01 | `lux_engine.dart` | `binaryPath` | Resolve path from common locations | Mock filesystem with `/usr/local/bin/lux` | Check `binaryPath` | Returns `/usr/local/bin/lux` |
| U-DL-LUX-02 | `lux_engine.dart` | `binaryPath` | **[EDGE]** Fallback to `which` if not in common paths | Mock `Process.runSync('which', ...)` | Check `binaryPath` | Returns path from `which` stdout |

## 2. Metadata Fetching

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-LUX-03 | `lux_engine.dart` | `fetchMetadata` | Parse standard Lux JSON | Mock `Process.stdout` with JSON containing `url`, `title`, `streams` | Call `fetchMetadata` | Returns `MediaInfo` with mapped formats |
| U-DL-LUX-04 | `lux_engine.dart` | `fetchMetadata` | Handle missing streams gracefully | Mock JSON missing `streams` object | Call `fetchMetadata` | Throws exception about empty metadata |
| U-DL-LUX-05 | `lux_engine.dart` | `fetchMetadata` | **[EDGE]** Handle partial JSON chunks | Mock `stdout` splitting JSON arbitrarily | Call `fetchMetadata` | Safely aggregates and parses, or throws catchable exception |
| U-DL-LUX-06 | `lux_engine.dart` | `fetchMetadata` | **[EDGE]** Process hangs without output | Mock process taking >10 minutes | Call `fetchMetadata` | Throws Timeout, cleans up process tree |

## 3. Download Execution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-LUX-07 | `lux_engine.dart` | `startDownload` | Construct proper `-f` argument | `format.formatId = 'mp4'` | Call `startDownload` | Args include `-f mp4` |
| U-DL-LUX-08 | `lux_engine.dart` | `startDownload` | **[EDGE]** Path contains spaces | Output path is `/tmp/my video/` | Call `startDownload` | Passes path properly quoted/escaped via Process |
| U-DL-LUX-05 | `lux_engine.dart` | `startDownload` | Construct download args | `format=MediaFormat(formatId: '1080p')` | Call `startDownload` | Args include `-O`, `-f 1080p`, `-n 16` |
