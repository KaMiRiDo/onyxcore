# Engine Registry Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/engine_registry.dart`
**Target Layer:** Services / Engines
**Coverage Target:** 100%

## 1. Engine Resolution — `resolveEngine`

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-01 | `engine_registry.dart` | `resolveEngine` | Return specific engine by preference | `preference = 'gallery-dl'` | Call `resolveEngine(url, 'gallery-dl')` | Returns `GalleryDlEngine` instance |
| U-DL-REG-02 | `engine_registry.dart` | `resolveEngine` | Fallback to yt-dlp for unknown preference | `preference = 'nonexistent'` | Call `resolveEngine(url, 'nonexistent')` | Returns `YtDlpEngine` (last required) |
| U-DL-REG-03 | `engine_registry.dart` | `resolveEngine` | Auto-detect highest-priority installed engine by URL pattern | URL = `https://instagram.com/post`, gallery-dl installed | Call `resolveEngine(url, 'auto')` | Returns `GalleryDlEngine` (priority 10, matches Instagram) |
| U-DL-REG-04 | `engine_registry.dart` | `resolveEngine` | Skip uninstalled engines in auto mode | URL matches `lux`, but `lux.isInstalled = false` | Call `resolveEngine(url, 'auto')` | Skips Lux, returns next matching engine |
| U-DL-REG-05 | `engine_registry.dart` | `resolveEngine` | Fallback to yt-dlp when no patterns match | URL = `https://random-unknown-site.com` | Call `resolveEngine(url, 'auto')` | Returns `YtDlpEngine` |

## 2. Engine Sequence Resolution — `resolveEngineSequence`

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-06 | `engine_registry.dart` | `resolveEngineSequence` | Return correct sequence for `auto` — matchers first by priority | URL = `https://youtube.com/...` | Call `resolveEngineSequence` | Sequence ordered: pattern matchers (high→low), then non-matchers (high→low) |
| U-DL-REG-07 | `engine_registry.dart` | `resolveEngineSequence` | Return single engine for specific preference | `preference = 'yt-dlp'` | Call `resolveEngineSequence(url, 'yt-dlp')` | Returns list with only `YtDlpEngine` |
| U-DL-REG-08 | `engine_registry.dart` | `resolveEngineSequence` | Fallback to yt-dlp when specific engine not found | `preference = 'nonexistent'` | Call `resolveEngineSequence(url, 'nonexistent')` | Returns list with `YtDlpEngine` |
| U-DL-REG-09 | `engine_registry.dart` | `resolveEngineSequence` | **[EDGE]** Handle no installed engines | All engines uninstalled | Call `resolveEngineSequence(url, 'auto')` | Returns list with `YtDlpEngine` (fallback) |
| U-DL-REG-10 | `engine_registry.dart` | `resolveEngineSequence` | Skip non-matching engines in `auto` mode | URL matches `bilibili.com` | Call `resolveEngineSequence` | Sequence puts `you-get` or `lux` first before general extractors |
| U-DL-REG-11 | `engine_registry.dart` | `resolveEngineSequence` | **[EDGE]** Priority ties — stable sort | Engine A and Engine B have same priority | Call `resolveEngineSequence` | Resolution maintains stable, predictable sort |

## 3. Global Installation Checks

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-12 | `engine_registry.dart` | `requiredInstalled` | Return true if both required engines present | `yt-dlp` and `gallery-dl` are installed | Check `requiredInstalled` | Returns `true` |
| U-DL-REG-13 | `engine_registry.dart` | `requiredInstalled` | **[EDGE]** Return false if ANY required engine missing | `yt-dlp` installed, but `gallery-dl` uninstalled | Check `requiredInstalled` | Returns `false` |
| U-DL-REG-14 | `engine_registry.dart` | `allInstalled` | Return true if ALL engines installed | All 6 engines installed | Check `allInstalled` | Returns `true` |
| U-DL-REG-15 | `engine_registry.dart` | `allInstalled` | Return false if any optional engine missing | 5 of 6 engines installed | Check `allInstalled` | Returns `false` |

## 4. Engine Lists & Lookup

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-16 | `engine_registry.dart` | `allEngines` | Return unmodifiable list of all 6 engines | - | Check `allEngines` | Returns list with 6 engines: GalleryDl, YtDlp, Streamlink, Lux, YouGet, Playwright |
| U-DL-REG-17 | `engine_registry.dart` | `requiredEngines` | Return unmodifiable list of 2 required engines | - | Check `requiredEngines` | Returns `[GalleryDlEngine, YtDlpEngine]` |
| U-DL-REG-18 | `engine_registry.dart` | `optionalEngines` | Return unmodifiable list of 4 optional engines | - | Check `optionalEngines` | Returns `[StreamlinkEngine, LuxEngine, YouGetEngine, PlaywrightEngine]` |
| U-DL-REG-19 | `engine_registry.dart` | `missingRequired` | Return list of missing required engines | `gallery-dl` not installed | Check `missingRequired` | Returns list containing `GalleryDlEngine` |
| U-DL-REG-20 | `engine_registry.dart` | `missingRequired` | Return empty list when all required installed | Both required installed | Check `missingRequired` | Returns `[]` |
| U-DL-REG-21 | `engine_registry.dart` | `findById` | Return engine matching ID | `id = 'yt-dlp'` | Call `findById('yt-dlp')` | Returns `YtDlpEngine` instance |
| U-DL-REG-22 | `engine_registry.dart` | `findById` | Return null if ID does not exist | `id = 'fake'` | Call `findById('fake')` | Returns `null` |

## 5. Dynamic Registration

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-REG-23 | `engine_registry.dart` | `register` | Add a custom engine to the registry | Custom `DownloadEngine` mock | Call `register(customEngine)` | `allEngines` contains the new engine |
