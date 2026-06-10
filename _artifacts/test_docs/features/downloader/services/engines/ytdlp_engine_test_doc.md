# YtDlpEngine Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/ytdlp_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** >90%

## 1. Environment & Path Resolution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YTD-01 | `ytdlp_engine.dart` | `binaryPath` | Resolve binary path to venv | Mock `HOME` environment variable | Access `binaryPath` | Returns `~/.local/share/onyxcore/yt-dlp-venv/bin/yt-dlp` |
| U-DL-YTD-02 | `ytdlp_engine.dart` | `isInstalled` | Return true when binary exists | Mock filesystem where binary file exists | Check `isInstalled` | Returns `true` |
| U-DL-YTD-03 | `ytdlp_engine.dart` | `isInstalled` | Return false when binary is missing | Mock filesystem where binary is absent | Check `isInstalled` | Returns `false` |

## 2. Metadata Fetching & Parsing (Shallow & Deep)

## 1. Process Execution & Arguments

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YTD-01 | `ytdlp_engine.dart` | `binaryPath` | Return bundled python venv binary | File exists at `~/.local/share/.../venv/bin/yt-dlp` | Check `binaryPath` | Returns absolute path to venv executable |
| U-DL-YTD-02 | `ytdlp_engine.dart` | `_buildEnv` | **[EDGE]** Force clean Python environment | User has global `PYTHONPATH` or `PYTHONHOME` set | Check `Process.start` env | `PYTHONPATH` and `PYTHONHOME` are stripped, `PYTHONUNBUFFERED=1` |
| U-DL-YTD-03 | `ytdlp_engine.dart` | `fetchMetadata` | Extract proxy configs from browser strings | `browser='Firefox'` | Call `fetchMetadata` | Args contain `--cookies-from-browser Firefox` |

## 2. Output Parsing & Errors

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YTD-04 | `ytdlp_engine.dart` | `fetchMetadata` | Construct single MediaInfo from JSON | Mock `stdout` stream emitting single JSON object | Call `fetchMetadata` | Returns List with 1 item |
| U-DL-YTD-05 | `ytdlp_engine.dart` | `fetchMetadata` | Construct multiple MediaInfo from ndjson | Mock `stdout` emitting multiple newline-separated JSONs | Call `fetchMetadata` | Returns List with multiple items |
| U-DL-YTD-06 | `ytdlp_engine.dart` | `fetchMetadata` | **[EDGE]** Hijacked stderr execution | Engine exits `0` but stdout is empty and stderr has warning | Call `fetchMetadata` | Throws Exception parsing `stderr` content |
| U-DL-YTD-07 | `ytdlp_engine.dart` | `fetchMetadata` | **[EDGE]** Timeout triggers partial hydration | Mock hanging process for >10 mins | Call `fetchMetadata` | Catches `TimeoutException`, kills tree, throws `PartialMetadataException` |

## 3. Download Logic

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-YTD-08 | `ytdlp_engine.dart` | `startDownload` | Use Aria2 if available | Mock `Aria2Accelerator.isAvailable = true` | Call `startDownload` | Args include `--downloader aria2c` |
| U-DL-YTD-09 | `ytdlp_engine.dart` | `startDownload` | **[EDGE]** Fallback if Aria2 missing | Mock `Aria2Accelerator.isAvailable = false` | Call `startDownload` | Falls back to native yt-dlp downloader |
| U-DL-YTD-10 | `ytdlp_engine.dart` | `startDownload` | **[EDGE]** Format selection string | Format is `id=137`, `audioOnly=true` | Call `startDownload` | Args include `-f 137+bestaudio/best` |
| U-DL-YTD-16 | `ytdlp_engine.dart` | `startDownload` | Construct safe filename output template | `title="My Video: Part 1"`, `isPlaylist=false` | Call `startDownload` | Args include `-o destination/My_Video__Part_1.%(ext)s` |
| U-DL-YTD-17 | `ytdlp_engine.dart` | `startDownload` | Construct playlist output template | `isPlaylist=true` | Call `startDownload` | Args include `-o destination/%(playlist_index)03d_%(title).80s.%(ext)s` |
| U-DL-YTD-18 | `ytdlp_engine.dart` | `startDownload` | Bypass dynamic scraping by injecting directUrl | `singleItemId='vid1'`, `directUrl='https://...'` | Call `startDownload` | Args include `--add-header Referer:originalUrl` and target is `directUrl` |
| U-DL-YTD-19 | `ytdlp_engine.dart` | `startDownload` | Inject aria2c accelerator if available | Mock `Aria2Accelerator.isAvailable=true` | Call `startDownload` | Args include `--external-downloader aria2c` |
