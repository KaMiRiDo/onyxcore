# Engine Registry Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/engine_registry.dart`
**Target Layer:** Services / Engines
**Coverage Target:** 100%

## 1. Engine Resolution & Auto Fallback Logic

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-01 | `engine_registry.dart` | `resolveEngineSequence` | Return correct sequence for `auto` | URL = `https://youtube.com/...` | Call `resolveEngineSequence` | Sequence ordered by engine priority where `isInstalled == true` |
| U-DL-REG-02 | `engine_registry.dart` | `resolveEngineSequence` | **[EDGE]** Handle requested engine missing/uninstalled | Request `engine='lux'`, but `lux.isInstalled` = false | Call `resolveEngineSequence` | Sequence drops Lux and returns other available engines |
| U-DL-REG-03 | `engine_registry.dart` | `resolveEngineSequence` | Skip non-matching engines in `auto` mode | URL matches `bilibili.com` | Call `resolveEngineSequence` | Sequence puts `you-get` or `lux` first before general extractors |
| U-DL-REG-04 | `engine_registry.dart` | `resolveEngineSequence` | **[EDGE]** Priority ties | Engine A and Engine B have priority 5 | Call `resolveEngineSequence` | Resolution maintains stable, predictable sort |

## 2. Global Installation Checks

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-05 | `engine_registry.dart` | `requiredInstalled` | Return true if base engines present | `yt-dlp` and `gallery-dl` are installed | Check `requiredInstalled` | Returns `true` |
| U-DL-REG-06 | `engine_registry.dart` | `requiredInstalled` | **[EDGE]** Return false if ANY required engine missing | `yt-dlp` installed, but `gallery-dl` uninstalled/corrupted | Check `requiredInstalled` | Returns `false` |
| U-DL-REG-07 | `engine_registry.dart` | `allEngines` | Ensure all engines instantiated exactly once | - | Check `allEngines` | Returns list of singletons |
| U-DL-REG-07 | `engine_registry.dart` | `requiredInstalled` | Return true if both GalleryDl and YtDlp are installed | Mock filesystem where both binaries exist | Check `requiredInstalled` | Returns `true`. |
| U-DL-REG-08 | `engine_registry.dart` | `requiredInstalled` | Return false if one required engine is missing | Mock filesystem where `gallery-dl` is missing | Check `requiredInstalled` | Returns `false`. |
| U-DL-REG-09 | `engine_registry.dart` | `missingRequired` | Return list of missing required engines | Mock filesystem where `gallery-dl` is missing | Check `missingRequired` | Returns list containing `GalleryDlEngine`. |
| U-DL-REG-10 | `engine_registry.dart` | `findById` | Return null if ID does not exist | `id = 'fake'` | Call `findById` | Returns `null`. |
