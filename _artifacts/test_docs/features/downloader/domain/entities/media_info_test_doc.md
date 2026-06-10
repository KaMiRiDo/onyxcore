# Media Info & Format Entities Unit Test Plan

**File Under Test:** `lib/features/downloader/domain/entities/media_info.dart`
**Target Layer:** Domain / Entities
**Coverage Target:** >95%

## 1. MediaFormat Tests

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-FMT-01 | `media_info.dart` | `MediaFormat.fromJson` | Parse standard format JSON correctly | `json` with `format_id`, `ext`, `resolution`, `filesize`, `format` | Call `MediaFormat.fromJson` | All fields correctly assigned. |
| U-DL-FMT-02 | `media_info.dart` | `MediaFormat.fromJson` | Construct resolution from `width` and `height` if `resolution` key missing | `json` with `width: 1920`, `height: 1080` but no `resolution` | Call `MediaFormat.fromJson` | `resolution` equals `"1920x1080"` |
| U-DL-FMT-03 | `media_info.dart` | `MediaFormat.fromJson` | Fallback to "audio only" if no resolution or dimensions exist | `json` without `resolution`, `width`, or `height` | Call `MediaFormat.fromJson` | `resolution` equals `"audio only"` |
| U-DL-FMT-04 | `media_info.dart` | `MediaFormat.fromJson` | Parse `filesize_approx` if `filesize` is null | `json` with `filesize: null`, `filesize_approx: 5000` | Call `MediaFormat.fromJson` | `filesize` equals `5000` |
| U-DL-FMT-05 | `media_info.dart` | `MediaFormat.toJson` | Serialize format object back to exact JSON structure | A `MediaFormat` instance with all optional fields filled | Call `toJson()` | Returns Map containing all keys matching the input JSON |
| U-DL-FMT-06 | `media_info.dart` | `MediaFormat.toJson` | Omit null fields in serialization | A `MediaFormat` instance with null optional fields | Call `toJson()` | Map does not contain keys for `vcodec`, `acodec`, `filesize`, `url` |
| U-DL-FMT-07 | `media_info.dart` | `operator ==` | Consider formats equal if `formatId` and `formatString` match | Two `MediaFormat` instances with identical IDs/Strings but different sizes | Compare with `==` | Returns `true` |
| U-DL-FMT-08 | `media_info.dart` | `hashCode` | Generate identical hash codes for equal objects | Two equal `MediaFormat` instances | Compare `.hashCode` | Hash codes match |

## 1. JSON Serialization & Parsing (Edge Cases)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-01 | `media_info.dart` | `MediaInfo.fromJson` | Parse complete standard yt-dlp metadata | Valid JSON map with `id`, `title`, `formats`, `duration` | Call `MediaInfo.fromJson` | Returns `MediaInfo` object with all fields correctly mapped |
| U-DL-MIN-02 | `media_info.dart` | `MediaInfo.fromJson` | Gracefully handle missing non-required fields | JSON map missing `filesize`, `thumbnail`, `duration` | Call `MediaInfo.fromJson` | Object created with missing fields set to `null` |
| U-DL-MIN-03 | `media_info.dart` | `MediaInfo.fromJson` | Extract `originalUrl` fallback logic | JSON missing `webpage_url`, contains `url` | Call `MediaInfo.fromJson` | `originalUrl` maps to `url` |
| U-DL-MIN-04 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle empty formats list | JSON map with `formats: []` | Call `MediaInfo.fromJson` | `formats` is empty list, no crash |
| U-DL-MIN-05 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle null formats list | JSON map with `formats: null` | Call `MediaInfo.fromJson` | `formats` is empty list, no crash |
| U-DL-MIN-06 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle incorrect data types | JSON map where `duration` is a String `"120"` instead of int | Call `MediaInfo.fromJson` | Cast fails gracefully or handles coercion safely |
| U-DL-MIN-07 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle corrupted formats object | JSON map where `formats` contains an int instead of Map | Call `MediaInfo.fromJson` | Skips corrupted format entry, parses the rest |

## 2. Format Extraction & Filtering

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-08 | `media_info.dart` | `MediaInfo.fromJson` | Extract and normalize `resolution` | JSON format contains `height: 1080` | Check formats list | Format `resolution` string is `'1080p'` |
| U-DL-MIN-09 | `media_info.dart` | `MediaInfo.fromJson` | Extract `filesize` or `filesize_approx` | JSON format contains `filesize_approx: 500` but no `filesize` | Check formats list | Format `filesize` maps to `500` |
| U-DL-MIN-10 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle formats missing both filesizes | JSON format has no `filesize` or `filesize_approx` | Check formats list | Format `filesize` is `null` |
| U-DL-MIN-11 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle duplicate format resolutions | JSON contains two formats with `1080p` | Check formats list | Both formats exist (no accidental overwriting) |

## 3. Playlist / Group Aggregation

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-12 | `media_info.dart` | `MediaGroup.totalFilesize` | Sum up sizes of all non-error items | `MediaGroup` with 3 items (sizes: 100, 200, null) | Evaluate `totalFilesize` | Returns `300` |
| U-DL-MIN-13 | `media_info.dart` | `MediaGroup.totalFilesize` | Exclude error items from total size | `MediaGroup` with 2 items (size: 100 valid, size: 200 `isError=true`) | Evaluate `totalFilesize` | Returns `100` |
| U-DL-MIN-14 | `media_info.dart` | `MediaGroup.totalFilesize` | **[EDGE]** Sum massive filesizes | `MediaGroup` with 3 items of 5GB each | Evaluate `totalFilesize` | Returns `15000000000` (int overflow check) |
| U-DL-MIN-15 | `media_info.dart` | `MediaGroup.totalFilesize` | **[EDGE]** Empty group total size | `MediaGroup` with 0 items | Evaluate `totalFilesize` | Returns `0` |

## 3. MediaGroup Tests

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GRP-01 | `media_info.dart` | `MediaGroup.isSingle` | Return true if 1 or 0 items in group | `MediaGroup` with 1 item | Check `isSingle` | Returns `true` |
| U-DL-GRP-02 | `media_info.dart` | `MediaGroup.imageCount` & `videoCount` | Correctly count based on `isVideo` flags | `MediaGroup` with 2 videos, 3 images | Check `imageCount`, `videoCount` | `imageCount=3`, `videoCount=2` |
| U-DL-GRP-03 | `media_info.dart` | `MediaGroup.totalFilesize` | Sum exact filesizes correctly if all have known sizes | Group with 2 items, sizes 10MB and 5MB | Check `totalFilesize` | Returns `15MB` (in bytes) |
| U-DL-GRP-04 | `media_info.dart` | `MediaGroup.totalFilesize` | Estimate missing video sizes using average of known videos | Group: Vid A (10MB), Vid B (null). | Check `totalFilesize` | Uses average: 10 + 10 = 20MB |
| U-DL-GRP-05 | `media_info.dart` | `MediaGroup.totalFilesize` | Fallback to hardcoded constants if NO items have known sizes | Group: Vid A (null), Img A (null) | Check `totalFilesize` | Vid uses 15MB fallback, Img uses 1MB fallback -> 16MB |
