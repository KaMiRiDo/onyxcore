# Download Config Entity Unit Test Plan

**File Under Test:** `lib/features/downloader/domain/entities/download_config.dart`
**Target Layer:** Domain / Entities
**Coverage Target:** 100%

## 1. DownloadMode Enum

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-01 | `download_config.dart` | `DownloadMode` | Contain exactly 3 values | - | Check `DownloadMode.values` | Contains `normal`, `mute`, `audioOnly` in order |
| U-DL-CFG-02 | `download_config.dart` | `DownloadMode` | Resolve by index | - | Access `DownloadMode.values[2]` | Returns `DownloadMode.audioOnly` |

## 2. GroupDownloadType Enum

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-03 | `download_config.dart` | `GroupDownloadType` | Contain exactly 3 values | - | Check `GroupDownloadType.values` | Contains `all`, `images`, `videos` in order |

## 3. Constructor & Default Values

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-04 | `download_config.dart` | `DownloadConfig()` | Create with all defaults | - | Call `DownloadConfig()` | `format` is `null`, `mode` is `normal`, `groupFilter` is `all`, `engine` is `'auto'`, `itemFormats` is empty map |
| U-DL-CFG-05 | `download_config.dart` | `DownloadConfig()` | Create with explicit values | Provide all named args | Call constructor with `format`, `mode`, `groupFilter`, `engine`, `itemFormats` | All fields match provided values |
| U-DL-CFG-06 | `download_config.dart` | `DownloadConfig()` | Initialize `itemFormats` to empty map when null | Pass `itemFormats: null` | Create instance | `itemFormats` is `{}` (not `null`) |
| U-DL-CFG-07 | `download_config.dart` | `DownloadConfig()` | Preserve explicit `itemFormats` map | `itemFormats` map with 3 entries | Create instance | `itemFormats.length` is 3 |

## 4. Field Mutability

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-08 | `download_config.dart` | `format` | Allow mutation of format field | Config with `format = null` | Set `config.format = MediaFormat(...)` | `config.format` is the new format |
| U-DL-CFG-09 | `download_config.dart` | `mode` | Allow mutation of mode field | Config with `mode = DownloadMode.normal` | Set `config.mode = DownloadMode.audioOnly` | `config.mode` is `audioOnly` |
| U-DL-CFG-10 | `download_config.dart` | `groupFilter` | Allow mutation of groupFilter field | Config with `groupFilter = GroupDownloadType.all` | Set `config.groupFilter = GroupDownloadType.videos` | `config.groupFilter` is `videos` |
| U-DL-CFG-11 | `download_config.dart` | `engine` | Allow mutation of engine field | Config with `engine = 'auto'` | Set `config.engine = 'gallery-dl'` | `config.engine` is `'gallery-dl'` |
| U-DL-CFG-12 | `download_config.dart` | `itemFormats` | Allow adding entries to itemFormats map | Config with empty `itemFormats` | Add entry `config.itemFormats['id1'] = format` | `itemFormats` contains 1 entry |

## 5. Engine Snapshot Comment Behavior

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-13 | `download_config.dart` | `engine` field | Default to `'auto'` for engine-agnostic fetch | - | Create `DownloadConfig()` | `engine` equals `'auto'` |
| U-DL-CFG-14 | `download_config.dart` | `engine` field | Capture specific engine at fetch time | `engine = 'yt-dlp'` | Create `DownloadConfig(engine: 'yt-dlp')` | `engine` equals `'yt-dlp'`, download uses this engine even if user switches later |
