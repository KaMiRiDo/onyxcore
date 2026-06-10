# Download Config Entity Unit Test Plan

**File Under Test:** `lib/features/downloader/domain/entities/download_config.dart`
**Target Layer:** Domain / Entities
**Coverage Target:** 100%

## 1. MediaFormat Resolution & Fallbacks

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-01 | `download_config.dart` | `getEffectiveFormat` | Return specifically overridden format for a single item | `itemFormats` map contains a format for `itemId` | Call `getEffectiveFormat(itemId, groupFormat)` | Returns item-specific format |
| U-DL-CFG-02 | `download_config.dart` | `getEffectiveFormat` | Fallback to group default format if item override missing | `itemFormats` map is empty | Call `getEffectiveFormat(itemId, groupFormat)` | Returns the `groupFormat` |
| U-DL-CFG-03 | `download_config.dart` | `getEffectiveFormat` | **[EDGE]** Handle null group default and null item override | `itemFormats` empty, `groupFormat` is null | Call `getEffectiveFormat` | Returns `null` |

## 2. Audio-Only Logic

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-04 | `download_config.dart` | `isAudioOnly` | Evaluate audio extraction state | `mode = DownloadMode.audioOnly` | Check `isAudioOnly` property | Returns `true` |
| U-DL-CFG-05 | `download_config.dart` | `isAudioOnly` | Evaluate normal extraction state | `mode = DownloadMode.normal` | Check `isAudioOnly` property | Returns `false` |

## 3. State Mutations

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CFG-06 | `download_config.dart` | `copyWith` | Mutate specific fields while preserving others | Config with `engine='yt-dlp'` | Call `copyWith(engine='aria2c')` | Returns new Config with `aria2c` but identical format/filters |
| U-DL-CFG-07 | `download_config.dart` | `copyWith` | **[EDGE]** Retain complex nested item formats | `itemFormats` contains 5 mappings | Call `copyWith(mode=audioOnly)` | New Config retains all 5 mappings perfectly by value |
