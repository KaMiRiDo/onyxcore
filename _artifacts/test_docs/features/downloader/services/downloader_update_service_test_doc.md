# DownloaderUpdateService Unit Test Plan

**File Under Test:** `lib/features/downloader/services/downloader_update_service.dart`
**Target Layer:** Services
**Coverage Target:** >85%

## 1. DownloaderUpdateState

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-01 | `downloader_update_service.dart` | `DownloaderUpdateState()` | Initialize with all defaults | - | Create `DownloaderUpdateState()` | `isUpdating=false`, `progress=0.0`, `error=null`, `engineProgress={}`, `installedVersions={}`, `latestVersions={}`, `isCheckingForUpdates=false` |
| U-DL-UPD-02 | `downloader_update_service.dart` | `DownloaderUpdateState.copyWith` | Override specific fields | State with defaults | Call `copyWith(isUpdating: true, progress: 0.5)` | `isUpdating=true`, `progress=0.5`, other fields unchanged |
| U-DL-UPD-03 | `downloader_update_service.dart` | `DownloaderUpdateState.copyWith` | Clear error via `clearError` flag | State with `error: 'failure'` | Call `copyWith(clearError: true)` | `error` is `null` |
| U-DL-UPD-04 | `downloader_update_service.dart` | `DownloaderUpdateState.copyWith` | Preserve error when `clearError` is false | State with `error: 'failure'` | Call `copyWith(progress: 0.5)` (no `clearError`) | `error` is still `'failure'` |

## 2. Update Checking

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-05 | `downloader_update_service.dart` | `checkForUpdates` | Query all engines for installed vs latest versions | Mock `EngineRegistry` with 2 engines | Call `checkForUpdates` | State updates `installedVersions` and `latestVersions` maps |
| U-DL-UPD-06 | `downloader_update_service.dart` | `checkForUpdates` | Prevent concurrent checks | Service is currently checking (`isCheckingForUpdates=true`) | Call `checkForUpdates` | Exits early, no secondary API calls |
| U-DL-UPD-07 | `downloader_update_service.dart` | `checkForUpdates` | Handle engine returning null version | Mock engine `getInstalledVersion()` returns `null` | Call `checkForUpdates` | Map does not contain key for that engine |
| U-DL-UPD-08 | `downloader_update_service.dart` | `checkForUpdates` | Set `isCheckingForUpdates` to false after completion | - | Call `checkForUpdates`, wait | `isCheckingForUpdates` is `false` |

## 3. Global Update (`updateAll`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-09 | `downloader_update_service.dart` | `updateAll` | Filter and update only engines with version mismatches | State where Engine A needs update, Engine B does not | Call `updateAll` | Only downloads Engine A |
| U-DL-UPD-10 | `downloader_update_service.dart` | `updateAll` | Handle `defaultOnly` flag — skip optional engines | Flag `defaultOnly = true`, Engine C is optional | Call `updateAll` | Skips Engine C even if update available |
| U-DL-UPD-11 | `downloader_update_service.dart` | `updateAll` | Prevent concurrent updates | `isUpdating` is already `true` | Call `updateAll` | Exits early |
| U-DL-UPD-12 | `downloader_update_service.dart` | `updateAll` | No-op when no engines need update | All versions match | Call `updateAll` | `isUpdating` set to false, no downloads triggered |
| U-DL-UPD-13 | `downloader_update_service.dart` | `updateAll` | Call `checkForUpdates` after completion | Update succeeds | Call `updateAll`, wait | `checkForUpdates` invoked in `finally` |
| U-DL-UPD-14 | `downloader_update_service.dart` | `updateAll` | **[EDGE]** Handle error during update | Download throws exception | Call `updateAll` | State has `error` set, `isUpdating=false` |

## 4. Binary Update (`updateBinaries`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-15 | `downloader_update_service.dart` | `updateBinaries` | Download all engines with `updateInfo` | 3 engines with updateInfo | Call `updateBinaries` | Downloads all 3, progress reaches 1.0 |
| U-DL-UPD-16 | `downloader_update_service.dart` | `updateBinaries` | Skip engines without `updateInfo` | 2 engines, only 1 has updateInfo | Call `updateBinaries` | Only 1 download triggered |
| U-DL-UPD-17 | `downloader_update_service.dart` | `updateBinaries` | Handle empty engines list | No engines have updateInfo | Call `updateBinaries` | `progress` set to 1.0 immediately |
| U-DL-UPD-18 | `downloader_update_service.dart` | `updateBinaries` | Create bin directory if missing | `~/.local/share/onyxcore/bin` doesn't exist | Call `updateBinaries` | Directory created recursively |
| U-DL-UPD-19 | `downloader_update_service.dart` | `updateBinaries` | **[EDGE]** Download failure sets error state | Network error during download | Call `updateBinaries` | `error` contains error message, `isUpdating=false` |

## 5. Single Engine Update (`updateEngine`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-20 | `downloader_update_service.dart` | `updateEngine` | Download binary for engine with `updateInfo` | Engine with `updateInfo` and `binaryPath` | Call `updateEngine` | Binary downloaded, `engineProgress` updated then cleaned up |
| U-DL-UPD-21 | `downloader_update_service.dart` | `updateEngine` | Initiate Python PIP install if engine type is Python | Mock `PythonEngine` with `engineType=python` | Call `updateEngine` | Calls `engine.install()`, tracks via progress |
| U-DL-UPD-22 | `downloader_update_service.dart` | `updateEngine` | Skip if no `updateInfo` and not Python engine | Engine with `updateInfo=null`, `engineType=cli` | Call `updateEngine` | Returns immediately, no state change |
| U-DL-UPD-23 | `downloader_update_service.dart` | `updateEngine` | Clean up `engineProgress` after successful update | - | Call `updateEngine`, wait | `engineProgress` map no longer contains engine ID |
| U-DL-UPD-24 | `downloader_update_service.dart` | `updateEngine` | **[EDGE]** Error sets error state with engine prefix | Download throws | Call `updateEngine` | `error` is `'engine-id:error message'` |

## 6. Process Engine Installation Tracking (`installProcessEngine`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-25 | `downloader_update_service.dart` | `installProcessEngine` | Track indeterminate progress (-1.0) while running | Mock process that completes | Call `installProcessEngine` | `engineProgress[id]` is `-1.0` during execution |
| U-DL-UPD-26 | `downloader_update_service.dart` | `installProcessEngine` | Handle exit code > 0 | Mock process exits with code 1 and stderr | Call `installProcessEngine` | `error` contains engine ID and stderr content |
| U-DL-UPD-27 | `downloader_update_service.dart` | `installProcessEngine` | Clean up progress after success | Mock process exits with code 0 | Call `installProcessEngine` | `engineProgress` no longer contains engine ID, `checkForUpdates` called |
| U-DL-UPD-28 | `downloader_update_service.dart` | `installProcessEngine` | No-op for null process future | `processFuture = null` | Call `installProcessEngine` | Returns immediately, no state change |
| U-DL-UPD-29 | `downloader_update_service.dart` | `installProcessEngine` | **[EDGE]** Process throws exception | Process future throws | Call `installProcessEngine` | `error` set with display name, progress cleaned up |

## 7. Release Download Logic (`_downloadLatestRelease`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-30 | `downloader_update_service.dart` | `_downloadLatestRelease` | Extract `.tar.gz` after downloading | Asset name ends in `.tar.gz` | Internal execution | Calls `tar -xzf`, deletes archive, sets `chmod +x` |
| U-DL-UPD-31 | `downloader_update_service.dart` | `_downloadLatestRelease` | Download plain binary (non-tar.gz) | Asset name ends in `.exe` or no extension | Internal execution | Writes directly to `savePath`, sets `chmod +x` |
| U-DL-UPD-32 | `downloader_update_service.dart` | `_downloadLatestRelease` | Verify SHA256 checksums if provided | Mock `checksumAssetName` with matching hash | Internal execution | Checksum passes, file preserved |
| U-DL-UPD-33 | `downloader_update_service.dart` | `_downloadLatestRelease` | **[EDGE]** Abort and delete file if checksum mismatch | Mock checksum file with different hash | Internal execution | File deleted, exception thrown with hash details |
| U-DL-UPD-34 | `downloader_update_service.dart` | `_downloadLatestRelease` | **[EDGE]** Asset not found in release | Release JSON contains no matching asset name | Internal execution | Throws `'Asset X not found in release'` |
| U-DL-UPD-35 | `downloader_update_service.dart` | `_downloadLatestRelease` | **[EDGE]** API returns non-200 status | Mock HTTP returning 404 | Internal execution | Throws `'Failed to fetch release info: 404'` |
| U-DL-UPD-36 | `downloader_update_service.dart` | `_downloadLatestRelease` | **[EDGE]** No assets in release | Release JSON has `assets: []` | Internal execution | Throws `'No assets found in the release'` |
| U-DL-UPD-37 | `downloader_update_service.dart` | `_downloadLatestRelease` | **[EDGE]** tar extraction failure | `tar` exits with non-zero code | Internal execution | Throws exception with tar stderr |
| U-DL-UPD-38 | `downloader_update_service.dart` | `_downloadLatestRelease` | Update progress during chunked download | Mock multi-chunk response | Internal execution | `state.progress` updates incrementally per chunk |
