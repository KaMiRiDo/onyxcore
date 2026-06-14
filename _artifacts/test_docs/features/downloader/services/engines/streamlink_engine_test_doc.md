# StreamlinkEngine Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/streamlink_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** >90%

## 1. Metadata Fetching — JSON Parsing

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-STR-01 | `streamlink_engine.dart` | `fetchMetadata` | Parse standard Streamlink JSON | Mock `Process.stdout` with `metadata`, `streams`, `plugin` | Call `fetchMetadata` | `MediaInfo` contains parsed live stream data, `isLive=true` |
| U-DL-STR-02 | `streamlink_engine.dart` | `fetchMetadata` | Handle internal Streamlink JSON error | Mock `Process.stdout` with `{"error": "Offline"}` | Call `fetchMetadata` | Throws Exception "Offline" |
| U-DL-STR-03 | `streamlink_engine.dart` | `fetchMetadata` | Extract correct platform name | URL contains `twitch.tv` vs `kick.com` vs `youtube.com` | Call `fetchMetadata` | `extractor` maps to 'Twitch', 'Kick', 'YouTube Live' |

## 2. Metadata Fetching — Quality Streams

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-STR-04 | `streamlink_engine.dart` | `fetchMetadata` | Parse available qualities | Mock `Process.stdout` with `Available streams: 720p (worst), 1080p (best)` | Call `fetchMetadata` | Returns `MediaInfo` with `720p` and `1080p` formats |
| U-DL-STR-05 | `streamlink_engine.dart` | `fetchMetadata` | Provide default fallback if parse fails | `Process.stdout` is garbage | Call `fetchMetadata` | Returns `MediaInfo` with single `'best'` fallback format |
| U-DL-STR-06 | `streamlink_engine.dart` | `fetchMetadata` | **[EDGE]** Timeout parsing streams | Streamlink hangs fetching metadata | Call `fetchMetadata` | Kills process via timeout, returns empty/partial |

## 3. Cancellation & Process Handling

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-STR-07 | `streamlink_engine.dart` | `cancelDownload` | Send SIGINT for graceful exit | Process is running | Call `cancelDownload` | `Process.kill(ProcessSignal.sigint)` is called |
| U-DL-STR-08 | `streamlink_engine.dart` | `cancelDownload` | Force kill if SIGINT hangs | Mock Process ignoring `sigint` | Call `cancelDownload` | Waits 3s, then calls `ProcessUtils.killProcessTree` |
| U-DL-STR-09 | `streamlink_engine.dart` | `cancelDownload` | **[EDGE]** Handle PID already terminated | Process died before `cancelDownload` called | Call `cancelDownload` | Safely catches `Exception` and returns cleanly |

## 4. Download Execution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-STR-10 | `streamlink_engine.dart` | `startDownload` | Construct proper live stream output args | `title=null` | Call `startDownload` | Args include `--output`, `--force`, `best` |
| U-DL-STR-11 | `streamlink_engine.dart` | `startDownload` | **[EDGE]** Process exits with code > 0 unexpectedly | Streamlink disconnects abruptly | Start process, push exit code `1` | Throws wrapped exception to facade |
