# OnyxCore — Recommended Updates

> **Audit Date:** 2026-08-23 | **Framework:** Flutter 3.44.4 / Dart SDK ^3.10.4 | **Platform:** Linux

---

## 1. Performance Issues

### 1.1 Downloader — Custom Extractor Execution Blocks the UI Thread
- **Location**: `lib/features/downloader/services/deno_extractor_runtime_service.dart`
- **Issue**: The entire `execute()` method awaits `process.exitCode` on the main Flutter isolate. Although the `await` is non-blocking, log streaming via `listen()` occurs on the main event loop. For extractors running for up to 30 seconds (the default `extractorTimeoutMs`), any synchronous work in the `onLog` callback could stall frame rendering.
- **Recommendation**: Run the `Process.start`, stream consuming, and `exitCode` await inside a `compute` isolate using `Isolate.run` and pass results back via a `ReceivePort`. If isolate overhead is undesirable, at minimum ensure `onLog` callbacks are lightweight and do not trigger `setState` synchronously.

---

### 1.2 Downloader — `DownloadsSharedController.recalculateFilteredStatistics()` Called on Every Notify
- **Location**: `lib/features/downloader/presentation/providers/downloads_shared_controller.dart`
- **Issue**: `recalculateFilteredStatistics()` iterates all `parsedItems` groups and their items on every `notifyListeners()` call. For large playlist imports (hundreds of items), this is a synchronous O(n) scan on the main thread that runs every rebuild cycle.
- **Recommendation**: Memoize statistics using a dirty flag. Set `_statisticsDirty = true` whenever `parsedItems` or `DownloadConfig` changes, compute lazily on the next getter call, and return cached values on subsequent reads without re-scanning.

---

### 1.3 Directory Browser — Sort Isolate Threshold May Miss Mid-Size Directories
- **Location**: `lib/features/directory_browser/presentation/providers/directory_providers.dart` — `sortedDirectoryItemsProvider`
- **Issue**: Sort is offloaded to a `compute` isolate only for directories with ≥500 items. On older/slower hardware, synchronous sorts of 200–499 items can still cause noticeable jank during rapid navigation.
- **Recommendation**: Lower the threshold to 100–150 items, or use `Isolate.run` unconditionally. The startup cost of spawning a compute isolate (~1–3ms) is negligible compared to a synchronous stall in the frame budget.

---

### 1.4 Image Viewer — 500 MB `imageCache.maximumSizeBytes` Limit Is Hard-Coded
- **Location**: `lib/main.dart` — engine initialization
- **Issue**: The global image cache is hard-coded to 500 MB. On systems with limited RAM (4–8 GB), this can trigger OS-level memory pressure when navigating large DSLR photo directories, as Flutter will not evict cached images until the 500 MB limit is hit.
- **Recommendation**: Make this configurable in Settings → Performance (e.g., "Image Cache Size: 100 MB / 250 MB / 500 MB"). Default to a lower value (128 MB) for general use and allow power users to raise it.

---

### 1.5 Video Player — libmpv Buffer Config Is Very Aggressive
- **Location**: `lib/features/video_player/presentation/widgets/video_preview_widget.dart` — mpv property setup
- **Issue**: `demuxer-max-bytes: 400 MiB` and `cache-secs: 60` are very aggressive for short clips or low-bitrate content. On machines with limited RAM, pre-allocating 600 MB of buffer memory (400 MB forward + 200 MB backward) per player instance can cause memory contention when multiple viewer windows are open simultaneously.
- **Recommendation**: Add a "Streaming Buffer" dropdown in Settings → Performance. Offer presets: `Minimal (64 MiB)`, `Balanced (128 MiB)` (default), `Aggressive (400 MiB)`. Apply dynamically based on detected available system RAM.

---

### 1.6 Audio Player — `AudioQueueIsolate` Rebuilds Full Queue on Any Directory Change
- **Location**: `lib/features/audio_player/domain/utils/audio_queue_isolate.dart`
- **Issue**: The audio queue is re-generated from scratch on every directory refresh event, even if only one file was added or removed.
- **Recommendation**: Implement a delta-patch approach — compute the diff of new vs. old file lists and only insert/remove changed tracks into the existing queue rather than rebuilding from scratch.

---

### 1.7 ThumbnailCacheService — No Maximum Cache Size Enforcement
- **Location**: `lib/core/cache/thumbnail_cache_service.dart`
- **Issue**: The Freedesktop thumbnail cache at `~/.cache/onyxcore/thumbnails/` has no size cap. On directories with thousands of RAW/HEIC/video files, the cache can grow unboundedly over time, consuming gigabytes of disk space.
- **Recommendation**: Add a periodic LRU eviction pass (e.g., on app startup, trim to the 5000 most-recently-accessed entries, or a configurable max disk size). Expose a "Clear Thumbnail Cache" button in Settings → Storage.

---

## 2. Risks

### 2.1 Custom Extractor — Deno Pinned Version May Become Unmaintained
- **Location**: `lib/features/downloader/services/deno_runtime.dart` — `pinnedVersion = 'v2.9.5'`
- **Risk**: Pinning to `v2.9.5` indefinitely means the app will never benefit from security patches or JS engine updates in Deno. If a critical CVE is found in Deno 2.9.x's network stack or V8, all users running extractors against untrusted pages will be exposed.
- **Recommendation**: Add a scheduled check (monthly / on app start) that compares `pinnedVersion` to the latest GitHub release. If a newer version is available, display a warning in Settings → Download Manager → Custom Extractors. Allow the user to trigger an update. Consider updating the pin in code with each app release.

---

### 2.2 Custom Extractor — Temp Directory Cleanup May Fail on Kill/Crash
- **Location**: `lib/features/downloader/services/deno_extractor_runtime_service.dart` — `finally` block
- **Risk**: The `finally` block calls `tempDir.delete(recursive: true)` after `process.kill()`. If the app is force-killed (SIGKILL, power loss) while an extractor is running, the temp directory at `/tmp/onyx_extractor_*` will be left on disk. Accumulated orphaned directories could consume significant disk space if the feature is used frequently.
- **Recommendation**: On app startup, scan `/tmp` for `onyx_extractor_*` directories and delete any that are older than 1 hour. This is a one-time O(1) scan on launch and requires no persistent state.

---

### 2.3 Custom Extractor — `Runtime.evaluate` Expression Concatenation Edge Case
- **Location**: `lib/features/downloader/services/deno_extractor_runtime_service.dart` — wrapper script `Runtime.evaluate` expression
- **Risk**: The wrapper script uses `JSON.stringify(userScriptContent)` to embed user script source into the `Runtime.evaluate` expression string via template literal concatenation. If `JSON.stringify` produces a string containing unusual Unicode or escape sequences that interact with the surrounding JS template literal, edge cases in very unusual user-authored scripts could produce unexpected parsing behavior in the eval string.
- **Recommendation**: Verify via unit test that scripts containing backticks, `${}`, and Unicode supplementary plane characters are correctly preserved end-to-end through the eval pipeline. The current architecture (reading script from file via `Deno.readTextFile` then embedding via `JSON.stringify`) is sound — confirm with regression tests.

---

### 2.4 Download Manager — SIGKILL on Download Processes May Corrupt Partial Files
- **Location**: `lib/app.dart` — `onWindowClose()` → `killProcessTreeSync()`
- **Risk**: `killProcessTreeSync()` is a synchronous SIGKILL cascade. If a `yt-dlp` process is in the middle of writing a partial file when killed, the output file will be corrupt. `yt-dlp` itself typically handles this gracefully when receiving `SIGTERM` but SIGKILL bypasses any cleanup handlers.
- **Recommendation**: In `onWindowClose()`, send `SIGTERM` first and wait up to 2 seconds (with a `Future.delayed`) before falling back to SIGKILL. This gives `yt-dlp` time to flush and rename the `.part` file. Since this is in the close handler, a 2-second delay is tolerable.

---

### 2.5 Download History — No Row Count Cap on `download_history` Table
- **Location**: `lib/features/downloader/services/download_history_database.dart`
- **Risk**: The download history table has no automatic pruning. Heavy users who perform thousands of downloads will accumulate unbounded rows in `~/.local/share/onyxcore/downloads.db`. The paginated `getAll(LIMIT 50)` keeps the UI fast, but `totalEntries` requires a full `COUNT(*)` scan which can become slow on very large tables (100k+ rows).
- **Recommendation**: Add an auto-prune policy: after each insert, if `totalEntries > 10,000` (configurable), delete the oldest N entries to bring count back to a cap. Expose a max-history-size setting in Settings → Download Manager.

---

### 2.6 Downloader — `Aria2Accelerator` Not Verified for Presence Before Use
- **Location**: `lib/features/downloader/services/aria2_accelerator.dart` — usage in `YtDlpEngine`
- **Risk**: If the `aria2c` binary is not installed on the system, injecting `--external-downloader aria2c` into `yt-dlp` args will cause downloads to silently fail. There is no pre-flight check for `aria2` presence before attempting to use it as an external downloader.
- **Recommendation**: Add `aria2` to the `EngineRegistry` as an optional dependency (or check via `which aria2c` at startup). If missing, suppress the `--external-downloader aria2c` flag and fall back to `yt-dlp`'s built-in downloader. Display an "Install aria2 for faster downloads" prompt in Settings.

---

### 2.7 Custom Extractor — Extractor ID Generation Uses Millisecond Timestamp
- **Location**: `lib/features/downloader/presentation/widgets/components/add_extractor_dialog.dart` — `_persist()` method
- **Risk**: Using `DateTime.now().millisecondsSinceEpoch.toString()` as the primary key is not collision-safe. If a user creates two extractors within the same millisecond (e.g., via rapid double-click or test automation), the second `upsertExtractor` call will silently overwrite the first.
- **Recommendation**: Use the `uuid` package (already in `pubspec.yaml`) to generate a `Uuid().v4()` ID instead of the timestamp.

---

### 2.8 DirectoryWatcher — Potential inotify File Descriptor Leak on Tab Close
- **Location**: `lib/core/platform/directory_watcher.dart`
- **Risk**: If a watcher subscription is created for a tab but the tab closes before the subscription's cancel completes asynchronously, the inotify file descriptor may remain open. On systems with a low `fs.inotify.max_user_watches` limit (default 8192), opening many tabs pointing to large directories could exhaust watch descriptors.
- **Recommendation**: Add a guard that immediately calls `subscription.cancel()` synchronously on tab disposal. Log a warning if the watch limit error `ENOSPC` is detected and display a user-visible notice recommending `sysctl fs.inotify.max_user_watches=524288`.

---

### 2.9 EngineRegistry — `allRequiredReady` Performs Synchronous Filesystem Calls on Every Invocation
- **Location**: `lib/features/downloader/services/engines/engine_registry.dart` — `allRequiredReady` getter
- **Risk**: `allRequiredReady` calls `isInstalled` on each engine, which calls `File(managedPath).existsSync()` (a synchronous filesystem call). `DownloaderReadinessNotifier.build()` is called from Riverpod on every panel open. Frequent panel open/close cycles will hammer the filesystem with sync I/O on the main isolate.
- **Recommendation**: Cache the `isInstalled` result per engine with a 10-second TTL. Invalidate the cache explicitly after `DownloaderUpdateNotifier.updateBinaries()` completes. This converts repeated panel opens from synchronous stat calls into in-memory reads.

---

## 3. Optimization Points

### 3.1 Custom Extractor — No Extractor Management UI in Settings
- **Location**: Settings Dialog → Download Manager section
- **Issue**: The `AddExtractorDialog` is accessible from the standalone downloader window but there is no dedicated list/management view in the Settings dialog for reviewing, editing, or deleting all saved extractors.
- **Recommendation**: Add a "Custom Extractors" subsection in Settings → Download Manager (similar to the "Installed Engines" section) showing a scrollable list of extractors with inline Edit and Delete actions.

---

### 3.2 Download History — No Full-Text Search
- **Location**: `lib/features/downloader/presentation/widgets/download_history_view.dart`
- **Issue**: Download history only supports date and status filters. Users cannot search by URL keyword, title substring, or destination path. With large history databases, finding a specific past download requires manual scrolling.
- **Recommendation**: Add a search text field to the `DownloadHistoryView` toolbar. Implement a SQLite `LIKE '%query%'` filter on `title` and `url` columns. Debounce the query by 300ms to avoid excessive DB calls on each keystroke.

---

### 3.3 Custom Extractor — No In-Dialog Test-Run Capability
- **Location**: `lib/features/downloader/presentation/widgets/components/add_extractor_dialog.dart`
- **Issue**: After creating a custom extractor, users have no in-dialog way to test it against a sample URL before saving. They must save, select it in the dropdown, enter a URL, and run the fetch to verify behavior.
- **Recommendation**: Add a "Test" button in `AddExtractorDialog` that takes a URL from a secondary text field and invokes `DenoExtractorRuntimeService.execute()` immediately. Display the extracted URLs (or error + logs) in an expandable inline section within the dialog.

---

### 3.4 Downloader — `DownloaderFilterOverlay` Uses a Global Static `OverlayEntry`
- **Location**: `lib/features/downloader/presentation/widgets/components/downloader_filter_overlay.dart`
- **Issue**: The static `_overlayEntry` singleton means only one filter overlay can exist at a time application-wide. If the owning widget is disposed without explicitly calling `hide()`, the `OverlayEntry` remains inserted in the overlay tree pointing to a garbage-collected widget.
- **Recommendation**: Register a `dispose` callback on the caller widget that calls `DownloaderFilterOverlay.hide()`. Alternatively, convert to an instance-based overlay managed by the widget (not static global state) and dispose it in the widget's `dispose()`.

---

### 3.5 Custom Extractor — `DefaultExtractorKind` Enum Is Not Extensible at Runtime
- **Location**: `lib/features/downloader/domain/services/default_extractor_template_service.dart`
- **Issue**: `DefaultExtractorKind` is a Dart `enum` with `html` as its only member. Adding a new kind (e.g., JSON API extractor, Network request interceptor) requires a code change and app release. The UI dropdown in `AddExtractorDialog` must also be manually updated.
- **Recommendation**: For Phase 3+, consider replacing the enum with a registry pattern (similar to `EngineRegistry`) where extractor kinds are registered by name and a `TemplateBuilder` function. The existing `extractorKind` JSON key approach already supports forward-compat via `firstOrNull` — the infrastructure is ready for extension.

---

### 3.6 Directory Browser — `DirectoryCache` TTL Is Fixed at 30 Seconds
- **Location**: `lib/core/cache/directory_cache.dart`
- **Issue**: The 30-second TTL is a hard-coded constant. On network filesystems (NFS, SAMBA) or slow external drives, 30 seconds may be too short. On local SSDs with inotify, 30 seconds is conservative since events already invalidate the cache; longer TTL would have no negative effect.
- **Recommendation**: Make the TTL configurable in Settings → Performance with presets: `Off (0s)`, `Short (10s)`, `Standard (30s)` (default), `Long (120s)`.

---

### 3.7 Window Management — OS Window Title Not Updated on Playlist Navigation
- **Location**: `lib/core/window_management/persistent_viewer_manager.dart`
- **Issue**: Secondary viewer windows (image, video, audio) do not update the OS-level window title when navigating between files in the playlist. The title stays as the initially-opened file name, making it difficult to identify individual viewer windows in the taskbar or window switcher (`Alt+Tab`).
- **Recommendation**: After each playlist navigation in the standalone viewers, call `windowManager.setTitle(fileName)` to update the OS window title to the currently-viewed file name.

---

### 3.8 Downloader — No Retry Mechanism for Failed Downloads
- **Location**: `lib/features/downloader/presentation/providers/download_task_provider.dart`
- **Issue**: When a download fails (`DownloadStatus.error`), users must manually re-trigger the download from scratch. There is no "Retry" action on failed task tiles.
- **Recommendation**: Add a "Retry" button on `DownloadTaskTile` for tasks in `error` state. Implement `retryDownload(id)` in `DownloadTaskNotifier` that re-creates the task with the same `url`, `destination`, and `args`, then starts it immediately.

---

### 3.9 Settings — `extractorBrowser` Dropdown Not Filtered to Chromium-Only
- **Location**: `lib/features/settings/presentation/widgets/settings_dialog.dart` — extractor browser dropdown
- **Issue**: The `extractorBrowser` setting dropdown likely shows all installed browsers (including Firefox, etc.), but `DenoExtractorRuntimeService` only supports `BrowserCapability.chromium`. Selecting a non-Chromium browser results in an unhelpful `ExtractorException` at runtime.
- **Recommendation**: Filter the `extractorBrowser` dropdown to only show browsers with `BrowserCapability.chromium`. Add a helper subtitle: "Only Chromium-based browsers are supported for custom extractors."

---

### 3.10 Testing — Custom Extractor Domain Layer Has No Unit Tests
- **Location**: `test/features/downloader/` — no test files exist for the new domain services
- **Issue**: `DefaultExtractorTemplateService`, `DefaultExtractorValidator`, and `ExtractorOutputValidator` are pure Dart classes specifically designed to be testable standalone (no Flutter/Riverpod dependencies). They contain security-critical logic (JS escaping, URL scheme validation, CSS selector validation) that is currently uncovered.
- **Recommendation**: Create:
  - `test/features/downloader/unit/domain/services/default_extractor_template_service_test.dart` — test `generateScript()` output for various selectors/attributes including edge cases (backticks, Unicode, injection patterns); test `encodeMetadata`/`decodeMetadata` round-trip and null/malformed handling
  - `test/features/downloader/unit/domain/services/default_extractor_validator_test.dart` — test all validation rules with valid/invalid inputs for name, CSS selector, and attribute name
  - `test/features/downloader/unit/domain/services/extractor_output_validator_test.dart` — test max results enforcement, non-string item rejection, scheme validation, empty URL rejection, deduplication

---

*Generated: 2026-08-23 | Full codebase audit covering 9 feature modules, core infrastructure, and services layer.*
