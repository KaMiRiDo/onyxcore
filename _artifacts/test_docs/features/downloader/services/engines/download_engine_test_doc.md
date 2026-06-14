# DownloadEngine Base Class Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/download_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** 100%

## 1. EngineType Enum

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-ENG-01 | `download_engine.dart` | `EngineType` | Contain exactly 4 values | - | Check `EngineType.values` | Contains `cli`, `python`, `script`, `api` in order |
| U-DL-ENG-02 | `download_engine.dart` | `EngineType` | Resolve by name | - | Access `EngineType.cli` | Returns correct enum value with index 0 |

## 2. EngineUpdateInfo

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-ENG-03 | `download_engine.dart` | `EngineUpdateInfo` | Create with all required fields | `apiUrl`, `assetName` provided | Construct `EngineUpdateInfo` | `apiUrl` and `assetName` match, `checksumAssetName` is `null` |
| U-DL-ENG-04 | `download_engine.dart` | `EngineUpdateInfo` | Create with optional checksum | `checksumAssetName` provided | Construct `EngineUpdateInfo` | `checksumAssetName` matches provided value |

## 3. PartialMetadataException

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-ENG-05 | `download_engine.dart` | `PartialMetadataException` | Store partial infos and message | `partialInfos` list with 3 items, `message = 'Timeout'` | Construct exception | `partialInfos.length` is 3, `message` is `'Timeout'` |
| U-DL-ENG-06 | `download_engine.dart` | `PartialMetadataException.toString` | Return message string | Exception with `message = 'Timed out after 10 minutes'` | Call `toString()` | Returns `'Timed out after 10 minutes'` |
| U-DL-ENG-07 | `download_engine.dart` | `PartialMetadataException` | Implement Exception interface | - | Check type | `is Exception` returns `true` |
| U-DL-ENG-08 | `download_engine.dart` | `PartialMetadataException` | **[EDGE]** Handle empty partialInfos | `partialInfos = []`, `message = 'No data'` | Construct exception | `partialInfos` is empty list, no crash |

## 4. DownloadEngine Default Implementations

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-ENG-09 | `download_engine.dart` | `systemDependencies` | Return empty list by default | Concrete subclass without override | Check `systemDependencies` | Returns `[]` |
| U-DL-ENG-10 | `download_engine.dart` | `isOptional` | Return false by default | Concrete subclass without override | Check `isOptional` | Returns `false` |
| U-DL-ENG-11 | `download_engine.dart` | `install` | Return null by default | Concrete subclass without override | Call `install()` | Returns `null` |
| U-DL-ENG-12 | `download_engine.dart` | `uninstall` | Return null by default | Concrete subclass without override | Call `uninstall()` | Returns `null` |
| U-DL-ENG-13 | `download_engine.dart` | `getInstalledVersion` | Return null by default | Concrete subclass without override | Call `getInstalledVersion()` | Returns `null` |
| U-DL-ENG-14 | `download_engine.dart` | `getLatestVersion` | Return null by default | Concrete subclass without override | Call `getLatestVersion()` | Returns `null` |
