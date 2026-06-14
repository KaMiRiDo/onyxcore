# DownloadsPanelHelpers Mixin Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/widgets/downloads_panel_helpers.dart`
**Target Layer:** Presentation / Widgets
**Coverage Target:** >95%

## 1. String Trimming & Formatting

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HLP-01 | `downloads_panel_helpers.dart` | `_trimMiddle` | Keep string as-is if shorter than maxLength | `text='Short'`, `maxLength=10` | Call `_trimMiddle` | Returns `'Short'` |
| U-DL-HLP-02 | `downloads_panel_helpers.dart` | `_trimMiddle` | Add ellipsis in middle if longer than maxLength | `text='This is a very long string'`, `maxLength=11` | Call `_trimMiddle` | Returns `'This...ring'` |
| U-DL-HLP-03 | `downloads_panel_helpers.dart` | `_formatDuration` | Format seconds < 60 | `seconds=45` | Call `_formatDuration` | Returns `'0:45'` |
| U-DL-HLP-04 | `downloads_panel_helpers.dart` | `_formatDuration` | Format minutes + seconds | `seconds=135` | Call `_formatDuration` | Returns `'2:15'` |
| U-DL-HLP-05 | `downloads_panel_helpers.dart` | `_formatDuration` | Format hours + minutes + seconds | `seconds=3725` | Call `_formatDuration` | Returns `'1:02:05'` |

## 2. Resolution & Height Parsing

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HLP-06 | `downloads_panel_helpers.dart` | `_formatResolution` | Return 'Unknown' for empty string | `res=''` | Call `_formatResolution` | Returns `'Unknown'` |
| U-DL-HLP-07 | `downloads_panel_helpers.dart` | `_formatResolution` | Return 'Audio Only' for audio | `res='audio'` | Call `_formatResolution` | Returns `'Audio Only'` |
| U-DL-HLP-08 | `downloads_panel_helpers.dart` | `_formatResolution` | Map dimensions to labels | `res='1920x1080'` | Call `_formatResolution` | Returns `'1080p'` |
| U-DL-HLP-09 | `downloads_panel_helpers.dart` | `_formatResolution` | Map 1440+ to 1440p | `res='2560x1440'` | Call `_formatResolution` | Returns `'1440p'` |
| U-DL-HLP-10 | `downloads_panel_helpers.dart` | `_formatResolution` | Map 2160+ to 4K | `res='3840x2160'` | Call `_formatResolution` | Returns `'4K'` |
| U-DL-HLP-11 | `downloads_panel_helpers.dart` | `_getHeight` | Extract height from 'WxH' format | `res='1920x1080'` | Call `_getHeight` | Returns `1080` |
| U-DL-HLP-12 | `downloads_panel_helpers.dart` | `_getHeight` | Extract height from plain numbers | `res='1080p'` | Call `_getHeight` | Returns `1080` |
| U-DL-HLP-13 | `downloads_panel_helpers.dart` | `_getHeight` | Extract height from named formats | `res='4K'` | Call `_getHeight` | Returns `2160` |

## 3. Format Matching (`matchTargetFormat`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HLP-14 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Return null if target is null | `targetFormat=null` | Call `matchTargetFormat` | Returns `null` |
| U-DL-HLP-15 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Return null if item has no formats | `item.formats = []` | Call `matchTargetFormat` | Returns `null` |
| U-DL-HLP-16 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Return exact match if available | Target format is in `item.formats` | Call `matchTargetFormat` | Returns the exact matching format |
| U-DL-HLP-17 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Fallback to audio if target is audio only | Target is 'audio only', exact match absent | Call `matchTargetFormat` | Returns best audio format from `item.formats` |
| U-DL-HLP-18 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Fallback to video <= target height | Target is 1080p | Call `matchTargetFormat` | Returns best video format <= 1080p |
| U-DL-HLP-19 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Prefer video without embedded audio | Two 1080p formats, one with audio, one without | Call `matchTargetFormat` | Returns the format WITHOUT audio |
| U-DL-HLP-20 | `downloads_panel_helpers.dart` | `matchTargetFormat` | Tie-break equal heights by filesize | Two 1080p formats, sizes 50MB and 60MB | Call `matchTargetFormat` | Returns the 60MB format |

## 4. File Size Calculation (`_getFormatBytes` & `_getFileSize`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HLP-21 | `downloads_panel_helpers.dart` | `_getFormatBytes` | Use format.filesize if available | `format.filesize = 100` | Call `_getFormatBytes` | Returns `100` |
| U-DL-HLP-22 | `downloads_panel_helpers.dart` | `_getFormatBytes` | Use `_resolvedFileSizes` cache if available | `format.filesize = null`, `_resolvedFileSizes[id] = 200` | Call `_getFormatBytes` | Returns `200` |
| U-DL-HLP-23 | `downloads_panel_helpers.dart` | `_getFormatBytes` | Trigger `_fetchLazySize` if URL present and cache miss | `format.filesize=null`, `item.directUrl='x'` | Call `_getFormatBytes` | Starts fetch, adds to `_fetchingFileSizes` |
| U-DL-HLP-24 | `downloads_panel_helpers.dart` | `_getFormatBytes` | Estimate combined size for video without audio | `config.mode=normal`, video format has no audio | Call `_getFormatBytes` | Returns video size + best audio size |
| U-DL-HLP-25 | `downloads_panel_helpers.dart` | `_getFormatBytes` | Estimate size for audio-only mode | `config.mode=audioOnly` | Call `_getFormatBytes` | Returns size of best audio format |
| U-DL-HLP-26 | `downloads_panel_helpers.dart` | `_getFileSize` | Format valid bytes as string | Bytes = 1024 | Call `_getFileSize` | Returns `'1.0 KB'` |

## 5. Group Size Calculation (`_getGroupBytes`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HLP-27 | `downloads_panel_helpers.dart` | `_getGroupBytes` | Ignore profiles and playlists in calculation | Group has 1 profile, 1 playlist, 1 video | Call `_getGroupBytes` | Returns bytes for only the video |
| U-DL-HLP-28 | `downloads_panel_helpers.dart` | `_getGroupBytes` | Respect `config.groupFilter` | `groupFilter=images`, group has 1 video, 1 image | Call `_getGroupBytes` | Returns bytes for only the image |
| U-DL-HLP-29 | `downloads_panel_helpers.dart` | `_getGroupBytes` | Estimate missing video sizes using average of known videos | Group: Vid A (10MB), Vid B (null) | Call `_getGroupBytes` | Returns `20971520` (20MB) |
| U-DL-HLP-30 | `downloads_panel_helpers.dart` | `_getGroupBytes` | Estimate missing image sizes using average of known images | Group: Img A (2MB), Img B (null) | Call `_getGroupBytes` | Returns `4194304` (4MB) |
| U-DL-HLP-31 | `downloads_panel_helpers.dart` | `_getGroupBytes` | Fallback to constants if no known sizes | Group: Vid(null), Img(null) | Call `_getGroupBytes` | Returns 15MB + 1MB in bytes |
