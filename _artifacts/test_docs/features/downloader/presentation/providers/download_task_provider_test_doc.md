# DownloadTaskProvider Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/providers/download_task_provider.dart`
**Target Layer:** Presentation / Providers
**Coverage Target:** >90%

## 1. Concurrency & Queue Management

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-01 | `download_task_provider.dart` | `_processQueue` | Limit concurrent active downloads based on settings | Mock `settingsProvider` `maxConcurrentDownloads = 2`, Queue 4 tasks via `startDownload` | Call `startDownload` repeatedly | 2 tasks are `running`, 2 tasks are `pending` |
| U-DL-TSK-02 | `download_task_provider.dart` | `_processQueue` | Start pending tasks when a running task completes | Initial state: 2 running, 2 pending | Complete one running task | 1 pending task transitions to `running`, 1 remains `pending` |
| U-DL-TSK-03 | `download_task_provider.dart` | `_processQueue` | **[EDGE]** Rapid queue flooding (Race Condition) | Loop 20 rapid `startDownload` calls asynchronously | Wait for event loop | Ensures queue does not lock up, exact `maxConcurrent` running |

## 2. Process Output Parsing (Regex Logic)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-04 | `download_task_provider.dart` | `_parseProgress` | Parse yt-dlp standard output | Process emits `[download]  13.0% of  107.0MiB at  16.0MiB/s ETA 00:05` | Route to `_parseProgress` | State updates: `progress=0.13`, `speed='16.0MiB/s'`, `eta='00:05'`, `totalSize='107.0MiB'` |
| U-DL-TSK-05 | `download_task_provider.dart` | `_parseProgress` | Track multi-item yt-dlp downloads | Process emits `[download] Downloading video 1 of 25` | Route to `_parseProgress` | State updates: `completedItems=0`, `totalItems=25`. Progress calculation formula adapts |
| U-DL-TSK-06 | `download_task_provider.dart` | `_parseProgress` | **[EDGE]** Enforce monotonic progress | Process emits `15%`, then drops to `10%` due to retry | Route to `_parseProgress` | UI state remains locked at `15%` to prevent reverse jumping |
| U-DL-TSK-07 | `download_task_provider.dart` | `_parseProgress` | **[EDGE]** Prevent float overflow | Custom math results in `progress = 1.05` | Route to `_parseProgress` | State capped exactly at `1.0` |

## 3. Task Cancellation & Cleanup

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-08 | `download_task_provider.dart` | `cancelDownload` | Kill process and mark cancelled | Task is `running` | Call `cancelDownload` | `ProcessUtils.killProcessTree` is called, status is `cancelled` |
| U-DL-TSK-09 | `download_task_provider.dart` | `cancelDownload` | **[EDGE]** Temp file cleanup handles locked files | File matches `.part` but is locked/permission denied | Call `cancelDownload` | Ignores `FileSystemException`, completes cancellation without crashing |
| U-DL-TSK-10 | `download_task_provider.dart` | `cancelDownload` | **[EDGE]** Live stream SIGINT handling hangs | Task is `running` live stream | Call `cancelDownload` | Sends `SIGINT` first, waits, then forces kill if it hangs |

## 4. History & Window Events

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-11 | `download_task_provider.dart` | `_startAutoRemovalTimer` | Transfer completed tasks to history after 3 seconds | Task status becomes `completed` | Wait 3 seconds | Task removed from state, added to `downloadHistoryProvider` |
| U-DL-TSK-12 | `download_task_provider.dart` | `onWindowClose` | **[EDGE]** Prevent zombie processes on window exit | Provider has 3 `running` tasks | Call `onWindowClose` | Calls `killProcessTreeSync` for all 3 PIDs sequentially |
