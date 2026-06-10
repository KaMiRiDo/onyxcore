# YouGetEngine Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/youget_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** >90%

## 1. Environment & Path Resolution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YGT-01 | `youget_engine.dart` | `binaryPath` | Resolve path from common locations | Mock filesystem with `/usr/local/bin/you-get` | Check `binaryPath` | Returns `/usr/local/bin/you-get` |
| U-DL-YGT-02 | `youget_engine.dart` | `binaryPath` | **[EDGE]** Fallback to `which` if not in common paths | Mock `Process.runSync('which', ...)` | Check `binaryPath` | Returns path from `which` stdout |

## 2. Metadata Fetching

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YGT-03 | `youget_engine.dart` | `fetchMetadata` | Parse You-Get standard JSON | Mock `Process.stdout` with You-Get JSON (`streams`, `site`, `title`) | Call `fetchMetadata` | Returns `MediaInfo` with formats mapped from streams |
| U-DL-YGT-04 | `youget_engine.dart` | `fetchMetadata` | Handle empty JSON blocks | Mock `Process.stdout` missing `streams` or empty JSON | Call `fetchMetadata` | Throws Exception mentioning empty metadata |
| U-DL-YGT-05 | `youget_engine.dart` | `fetchMetadata` | Handle process errors | Mock process exiting with code `1` and stderr | Call `fetchMetadata` | Throws Exception containing `stderr` text |
| U-DL-YGT-06 | `youget_engine.dart` | `fetchMetadata` | **[EDGE]** Malformed JSON array | Mock `Process.stdout` returning partially cut off JSON | Call `fetchMetadata` | Safely catches JSON parsing error without crashing |

## 3. Download Execution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YGT-07 | `youget_engine.dart` | `startDownload` | Construct download args with format ID | `format.formatId = 'flv'` | Call `startDownload` | Args contain `--format=flv` and output path |
| U-DL-YGT-08 | `youget_engine.dart` | `startDownload` | **[EDGE]** Missing output directory | Directory does not exist on disk | Call `startDownload` | Process wrapper handles exit code safely |
| U-DL-YGT-06 | `youget_engine.dart` | `startDownload` | Construct download args | `format=MediaFormat(formatId: 'mp4')`, `title='vid'` | Call `startDownload` | Args include `-O vid`, `--format=mp4`, `-o destination` |
