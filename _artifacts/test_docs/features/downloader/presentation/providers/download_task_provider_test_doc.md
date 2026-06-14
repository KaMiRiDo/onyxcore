# DownloadTaskProvider Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/providers/download_task_provider.dart`
**Target Layer:** Presentation / Providers
**Coverage Target:** >90%

## 1. DownloadTask Entity

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-01 | `download_task_provider.dart` | `DownloadTask()` | Create with all defaults | Only required fields (`id`, `url`, `destination`, `title`, `createdAt`) | Construct | `status=pending`, `progress=0.0`, `speed=''`, `eta=''`, `totalSize=''`, `expectedBytes=0`, `downloadedBytes=0`, `completedItems=0`, `totalItems=0`, `error=null`, `process=null`, `logs=[]`, `completedAt=null` |
| U-DL-TSK-02 | `download_task_provider.dart` | `DownloadTask.copyWith` | Override specific fields | Task with `progress=0.0` | Call `copyWith(progress: 0.5, speed: '2MB/s')` | `progress=0.5`, `speed='2MB/s'`, all other fields unchanged |
| U-DL-TSK-03 | `download_task_provider.dart` | `DownloadTask.copyWith` | Preserve `id`, `url`, `destination`, `createdAt` (immutable) | Task with specific values | Call `copyWith(...)` | `id`, `url`, `destination`, `createdAt` unchanged (no setter) |

## 2. DownloadStatus Enum

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-04 | `download_task_provider.dart` | `DownloadStatus` | Contain exactly 6 values | - | Check `DownloadStatus.values` | Contains `pending`, `running`, `cancelling`, `completed`, `error`, `cancelled` |

## 3. Queue Management

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-05 | `download_task_provider.dart` | `startDownload` | Add task in pending state and process queue | No running tasks | Call `startDownload` | Task added to state with `status=pending`, then immediately processed to `running` |
| U-DL-TSK-06 | `download_task_provider.dart` | `_processQueue` | Respect `maxConcurrentDownloads` limit | 3 running, limit is 3, 2 pending | Invoke `_processQueue` | No new tasks started |
| U-DL-TSK-07 | `download_task_provider.dart` | `_processQueue` | Start pending tasks when slots free | 2 running, limit is 3, 2 pending | Invoke `_processQueue` | 1 pending task promoted to running |
| U-DL-TSK-08 | `download_task_provider.dart` | `_processQueue` | **[EDGE]** Queue drains after error/completion | Running task completes → slot frees | `_processQueue` called in `finally` | Next pending task starts |

## 4. Progress Parsing — yt-dlp

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-09 | `download_task_provider.dart` | `_parseProgress` | Parse standard yt-dlp: `[download]  13.0% of  107.0MiB at  16.0MiB/s ETA 00:05` | - | Call with stdout line | `progress=0.13`, `totalSize='107.0MiB'`, `speed='16.0MiB/s'`, `eta='00:05'` |
| U-DL-TSK-10 | `download_task_provider.dart` | `_parseProgress` | Parse yt-dlp with unknown size: `[download]  13.0% of ~10.0MiB at Unknown B/s ETA Unknown` | - | Call with stdout line | `progress=0.13`, `totalSize='~10.0MiB'`, `speed='Unknown B/s'`, `eta='Unknown'` |
| U-DL-TSK-11 | `download_task_provider.dart` | `_parseProgress` | Parse yt-dlp 100%: `[download] 100% of 10.0MiB in 00:01` | - | Call with stdout line | `progress=1.0` |
| U-DL-TSK-12 | `download_task_provider.dart` | `_parseProgress` | Parse playlist item index: `[download] Downloading video 1 of 25` | `totalItems` from args | Call with stdout line | `completedItems=0` (1-based → completed = index-1), `totalItems=25` |
| U-DL-TSK-13 | `download_task_provider.dart` | `_parseProgress` | **[EDGE]** Strip ANSI escape codes before parsing | Line includes `\x1B[32m[download]\x1B[0m  50.0%...` | Call with ANSI line | Parsed correctly as 50% |

## 5. Progress Parsing — Fragmented Downloads

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-14 | `download_task_provider.dart` | `_parseProgress` | Parse `[download] Frag 1/10` | - | Call with stdout line | `progress=0.10`, `totalSize='1 / 10 Frags'` |
| U-DL-TSK-15 | `download_task_provider.dart` | `_parseProgress` | Parse `[download] Frag 10/10` | - | Call with stdout line | `progress=1.0`, `totalSize='10 / 10 Frags'` |

## 6. Progress Parsing — Unknown Total Size

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-16 | `download_task_provider.dart` | `_parseProgress` | Parse `[download] 10.0MiB at 5.0MiB/s` (no percentage) | - | Call with stdout line | `progress=0.0`, `speed='5.0MiB/s'`, `totalSize='10.0MiB / ?'` |

## 7. Progress Parsing — aria2c

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-17 | `download_task_provider.dart` | `_parseProgress` | Parse aria2c: `[#bb8141 1.7MiB/113MiB(1%) CN:16 DL:2.7MiB ETA:41s]` | - | Call with stdout line | `progress=0.01`, `totalSize='1.7MiB / 113MiB'`, `speed='2.7MiB'`, `eta='41s'` |
| U-DL-TSK-18 | `download_task_provider.dart` | `_parseProgress` | Parse aria2c download complete: `Download complete:` | Single-item task | Call with stdout line | `progress=1.0` |
| U-DL-TSK-19 | `download_task_provider.dart` | `_parseProgress` | **[EDGE]** aria2c download complete on multi-item task | `totalItems=5` | Call with `Download complete:` | Progress NOT set to 1.0 (multi-item download) |

## 8. Progress Parsing — You-Get

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-20 | `download_task_provider.dart` | `_parseProgress` | Parse `98.5% ( 24.0/ 24.4MB) [==============>`| - | Call with stdout line | `progress≈0.985`, `totalSize='24.4 MB'` |
| U-DL-TSK-21 | `download_task_provider.dart` | `_parseProgress` | Parse You-Get download complete: `(✓)` + `Downloaded to:` | - | Call with stdout line | `progress=1.0` |

## 9. Progress Parsing — Lux

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-22 | `download_task_provider.dart` | `_parseProgress` | Parse `50.00% \|████████░░░░\| 25.0/50.0 MiB 5.0 MiB/s 5s` | - | Call with stdout line | `progress=0.5`, `totalSize='25.0/50.0 MiB'`, `speed='5.0 MiB/s'`, `eta='5s'` |

## 10. Progress Parsing — FFmpeg (Playwright Pipeline)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-23 | `download_task_provider.dart` | `_parseProgress` | Parse `time=00:01:30` | - | Call with stdout line | `totalSize='Elapsed: 00:01:30'` |

## 11. Progress Parsing — Streamlink & Gallery-dl

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-24 | `download_task_provider.dart` | `_parseProgress` | Handle `Writing output to` Streamlink trigger | Task with destination | Call with `Writing output to /path/file.ts` | Starts file size monitor (calls `_startFileSizeMonitor`) |
| U-DL-TSK-25 | `download_task_provider.dart` | `_parseProgress` | Handle `Stream ended` Streamlink trigger | - | Call with `Stream ended` | Starts file size monitor if not already running |
| U-DL-TSK-26 | `download_task_provider.dart` | `_parseProgress` | Gallery-dl: count completed file by extension match | engine='gallery-dl', line='/path/file.jpg' | Call with line | `completedItems` incremented |
| U-DL-TSK-27 | `download_task_provider.dart` | `_parseProgress` | Gallery-dl: skip log messages starting with `[` | engine='gallery-dl', line='[gallery-dl] Starting...' | Call with line | No increment |
| U-DL-TSK-28 | `download_task_provider.dart` | `_parseProgress` | Gallery-dl: count file paths with `/` | engine='gallery-dl', line='/home/dl/img.webp' | Call with line | `completedItems` incremented |

## 12. Multi-Item Progress Aggregation

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-29 | `download_task_provider.dart` | `updateWithProgress` | Aggregate progress across multiple items | `totalItems=25`, `completedItems=3`, current item at 45% | Parse progress | `progress = (300+45)/2500 = 0.138` |
| U-DL-TSK-30 | `download_task_provider.dart` | `updateWithProgress` | **[EDGE]** Enforce monotonic progress | Previous progress was `0.5`, new calculated is `0.3` | Parse progress line | `progress` stays at `0.5` |
| U-DL-TSK-31 | `download_task_provider.dart` | `updateWithProgress` | Cap progress at 1.0 | Calculated progress > 1.0 | Parse progress | `progress = 1.0` |
| U-DL-TSK-32 | `download_task_provider.dart` | `updateWithProgress` | Only update speed/eta with non-empty values | Speed = '' (empty), eta = '' | Parse progress | Speed and eta fields not cleared |

## 13. Download Lifecycle

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-33 | `download_task_provider.dart` | `_startProcessForTask` | Transition to completed on exit code 0 | Process exits with 0 | Wait for exit | `status=completed`, `progress=1.0`, `completedAt` is set |
| U-DL-TSK-34 | `download_task_provider.dart` | `_startProcessForTask` | Transition to error on non-zero exit code | Process exits with 1 | Wait for exit | `status=error`, `error='Process exited with code 1'` |
| U-DL-TSK-35 | `download_task_provider.dart` | `_startProcessForTask` | Remain cancelled if status was already cancelled | Task cancelled, then process exits with 1 | Wait for exit | `status` stays `cancelled`, NOT overwritten to `error` |
| U-DL-TSK-36 | `download_task_provider.dart` | `_startProcessForTask` | Start folder size monitor for playlists/profiles | `isPlaylist=true` | Start process | `_startFolderSizeMonitor` called |
| U-DL-TSK-37 | `download_task_provider.dart` | `_startProcessForTask` | Call `_processQueue` in finally block | Process exits | Wait | Queue processes next pending task |

## 14. Cancellation

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-38 | `download_task_provider.dart` | `cancelDownload` | Show cancelling intermediate state | Task is running | Call `cancelDownload` | Status transitions: `running` → `cancelling` → `cancelled` |
| U-DL-TSK-39 | `download_task_provider.dart` | `cancelDownload` | Use SIGINT for live streams, then force kill | `isLive=true`, process alive | Call `cancelDownload` | Sends SIGINT, waits 3s, then kills tree |
| U-DL-TSK-40 | `download_task_provider.dart` | `cancelDownload` | Use `killProcessTree` for normal downloads | `isLive=false`, process alive | Call `cancelDownload` | Calls `ProcessUtils.killProcessTree` directly |
| U-DL-TSK-41 | `download_task_provider.dart` | `cancelDownload` | Stop live monitor if running | Task has active live monitor | Call `cancelDownload` | Timer cancelled and removed |
| U-DL-TSK-42 | `download_task_provider.dart` | `cancelDownload` | Clean up temp files after cancel | Task with destination and title | Call `cancelDownload` | `_cleanupTempFiles` called |

## 15. Temp File Cleanup

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-43 | `download_task_provider.dart` | `_cleanupTempFiles` | Remove `.temp`, `.part`, `.ytdl`, `.aria2`, `.frag` files | Directory with these files | Call `_cleanupTempFiles` | All temp files deleted |
| U-DL-TSK-44 | `download_task_provider.dart` | `_cleanupTempFiles` | In dedicated folder: delete ALL temp files | `isDedicatedFolder=true` | Call `_cleanupTempFiles` | All matching files deleted regardless of title |
| U-DL-TSK-45 | `download_task_provider.dart` | `_cleanupTempFiles` | In shared folder: only delete files matching title | `isDedicatedFolder=false`, `title='My Video'` | Call `_cleanupTempFiles` | Only `My_Video.part` deleted, `Other.part` preserved |
| U-DL-TSK-46 | `download_task_provider.dart` | `_cleanupTempFiles` | **[EDGE]** Handle non-existent directory | Directory doesn't exist | Call `_cleanupTempFiles` | No crash, returns silently |
| U-DL-TSK-47 | `download_task_provider.dart` | `_cleanupTempFiles` | **[EDGE]** Handle file deletion exception | File locked by another process | Call `_cleanupTempFiles` | Swallows exception, continues cleanup |

## 16. Task Removal & History Archival

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-48 | `download_task_provider.dart` | `removeTask` | Remove task from state and clean up args | Task in state | Call `removeTask` | State no longer contains task, `_taskArgs` and `_downloadedCounts` cleaned |
| U-DL-TSK-49 | `download_task_provider.dart` | `clearHistory` | Keep only running/pending/cancelling tasks | 3 running, 2 completed, 1 error | Call `clearHistory` | State contains only 3 running tasks |
| U-DL-TSK-50 | `download_task_provider.dart` | `_startAutoRemovalTimer` | Archive to history and remove after 3 seconds | Completed task | Wait 3 seconds | `downloadHistoryProvider.addEntry` called, task removed from state |
| U-DL-TSK-51 | `download_task_provider.dart` | `_startAutoRemovalTimer` | Not create duplicate timers | Timer already exists for ID | Call status update | No second timer created |

## 17. Hydration Callback

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-52 | `download_task_provider.dart` | `onHydrationFinished` | Update totalItems for matching URL | Running task with URL 'x', items list of 20 | Call `onHydrationFinished('x', items)` | `totalItems=20`, progress recalculated |
| U-DL-TSK-53 | `download_task_provider.dart` | `onHydrationFinished` | Respect filterType 'images' | `filterType='images'`, items: 5 videos, 15 images | Call `onHydrationFinished` | `totalItems=15` (only images counted) |
| U-DL-TSK-54 | `download_task_provider.dart` | `onHydrationFinished` | Respect filterType 'videos' | `filterType='videos'`, items: 5 videos, 15 images | Call `onHydrationFinished` | `totalItems=5` (only videos counted) |
| U-DL-TSK-55 | `download_task_provider.dart` | `onHydrationFinished` | No-op for non-matching URLs | Running task with URL 'x' | Call `onHydrationFinished('y', items)` | No state change |

## 18. Live Monitoring

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-56 | `download_task_provider.dart` | `_startFileSizeMonitor` | Poll file size every 2 seconds | `.ts` file exists and growing | Timer fires | `totalSize` updated with formatted bytes, `speed` calculated |
| U-DL-TSK-57 | `download_task_provider.dart` | `_startFileSizeMonitor` | Try `.ts` then `.mp4` extensions | `.mp4` file exists (not `.ts`) | Timer fires | Finds and monitors `.mp4` file |
| U-DL-TSK-58 | `download_task_provider.dart` | `_startFolderSizeMonitor` | Poll folder size every 1 second | Folder with files, task is running | Timer fires | `downloadedBytes` updated |
| U-DL-TSK-59 | `download_task_provider.dart` | `_startFolderSizeMonitor` | **[EDGE]** Skip if monitor already exists | Monitor already running for this ID | Call `_startFolderSizeMonitor` | Does not create duplicate timer |

## 19. Zombie Process Prevention

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-60 | `download_task_provider.dart` | `onWindowClose` | Kill all running/cancelling processes on window close | 2 running tasks with PIDs | Call `onWindowClose` | `ProcessUtils.killProcessTreeSync` called for both PIDs |
| U-DL-TSK-61 | `download_task_provider.dart` | `onWindowClose` | Skip non-running tasks | 1 completed task | Call `onWindowClose` | No kill attempted |

## 20. Derived Providers

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-62 | `download_task_provider.dart` | `activeDownloadTaskProvider` | Filter running/pending tasks | 2 running, 1 pending, 3 completed | Watch provider | Returns 3 tasks |
| U-DL-TSK-63 | `download_task_provider.dart` | `completedDownloadTaskProvider` | Filter completed/error/cancelled tasks | 2 running, 1 completed, 1 error, 1 cancelled | Watch provider | Returns 3 tasks |

## 21. Log Appending

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-TSK-64 | `download_task_provider.dart` | `_appendLog` | Add non-empty trimmed lines to logs | Data with 3 non-empty lines and 1 empty | Call `_appendLog` | `logs` grows by 3 |
| U-DL-TSK-65 | `download_task_provider.dart` | `_appendLog` | **[EDGE]** Skip whitespace-only lines | Data is `'  \n  \n  '` | Call `_appendLog` | No new lines added |
