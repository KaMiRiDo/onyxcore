# DownloaderUpdateService Unit Test Plan

**File Under Test:** `lib/features/downloader/services/downloader_update_service.dart`
**Target Layer:** Services
**Coverage Target:** >85%

## 1. Update Checking

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-01 | `downloader_update_service.dart` | `checkForUpdates` | Query all engines for installed vs latest versions | Mock `EngineRegistry` with 2 engines | Call `checkForUpdates` | State updates `installedVersions` and `latestVersions` maps |
| U-DL-UPD-02 | `downloader_update_service.dart` | `checkForUpdates` | Prevent concurrent checks | Service is currently checking | Call `checkForUpdates` | Exits early, no secondary API calls |

## 2. Global Update & Binaries Update

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-03 | `downloader_update_service.dart` | `updateAll` | Filter and update only engines with mismatches | State where Engine A needs update, Engine B does not | Call `updateAll` | Only downloads Engine A |
| U-DL-UPD-04 | `downloader_update_service.dart` | `updateAll` | Handle `defaultOnly` flag | Flag `defaultOnly = true`, Engine C is optional | Call `updateAll` | Skips Engine C even if update available |

## 3. Single Engine Updates & HTTP Logic

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-UPD-05 | `downloader_update_service.dart` | `updateEngine` | Initiate Python PIP update if type is Python | Mock `PythonEngine` | Call `updateEngine` | Calls `engine.install()`, tracks via `installProcessEngine` |
| U-DL-UPD-06 | `downloader_update_service.dart` | `_downloadLatestRelease` | Extract `.tar.gz` after downloading | Asset name ends in `.tar.gz` | Internal execution | Calls `tar -xzf`, deletes archive, sets `chmod +x` |
| U-DL-UPD-07 | `downloader_update_service.dart` | `_downloadLatestRelease` | Verify SHA256 checksums if provided | Mock `checksumAssetName` | Internal execution | Aborts and deletes file if checksum mismatch |
