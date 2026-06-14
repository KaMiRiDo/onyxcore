# Media Info & Format Entities Unit Test Plan

**File Under Test:** `lib/features/downloader/domain/entities/media_info.dart`
**Target Layer:** Domain / Entities
**Coverage Target:** >95%

## 1. MediaFormat — JSON Parsing

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-FMT-01 | `media_info.dart` | `MediaFormat.fromJson` | Parse standard format JSON correctly | `json` with `format_id`, `ext`, `resolution`, `filesize`, `format` | Call `MediaFormat.fromJson` | All fields correctly assigned |
| U-DL-FMT-02 | `media_info.dart` | `MediaFormat.fromJson` | Construct resolution from `width` and `height` if `resolution` key missing | `json` with `width: 1920`, `height: 1080` but no `resolution` | Call `MediaFormat.fromJson` | `resolution` equals `"1920x1080"` |
| U-DL-FMT-03 | `media_info.dart` | `MediaFormat.fromJson` | Fallback to "audio only" if no resolution or dimensions exist | `json` without `resolution`, `width`, or `height` | Call `MediaFormat.fromJson` | `resolution` equals `"audio only"` |
| U-DL-FMT-04 | `media_info.dart` | `MediaFormat.fromJson` | Parse `filesize_approx` if `filesize` is null | `json` with `filesize: null`, `filesize_approx: 5000` | Call `MediaFormat.fromJson` | `filesize` equals `5000` |
| U-DL-FMT-05 | `media_info.dart` | `MediaFormat.fromJson` | Default empty strings for missing required fields | `json` missing `format_id`, `ext`, `format` | Call `MediaFormat.fromJson` | `formatId` is `''`, `extension` is `''`, `formatString` is `''` |
| U-DL-FMT-06 | `media_info.dart` | `MediaFormat.fromJson` | Parse nullable codec fields | `json` with `vcodec: 'avc1'`, `acodec: 'mp4a'` | Call `MediaFormat.fromJson` | `videoCodec` is `'avc1'`, `audioCodec` is `'mp4a'` |
| U-DL-FMT-07 | `media_info.dart` | `MediaFormat.fromJson` | **[EDGE]** `format_id` is an integer in JSON | `json` with `format_id: 137` (int, not String) | Call `MediaFormat.fromJson` | `formatId` equals `'137'` (toString conversion) |

## 2. MediaFormat — JSON Serialization

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-FMT-08 | `media_info.dart` | `MediaFormat.toJson` | Serialize format object back to exact JSON structure | A `MediaFormat` instance with all optional fields filled | Call `toJson()` | Returns Map containing all keys matching the input JSON |
| U-DL-FMT-09 | `media_info.dart` | `MediaFormat.toJson` | Omit null fields in serialization | A `MediaFormat` instance with null optional fields | Call `toJson()` | Map does not contain keys for `vcodec`, `acodec`, `filesize`, `url`, `format_note` |
| U-DL-FMT-10 | `media_info.dart` | `MediaFormat.toJson` / `fromJson` | Round-trip serialization | Create format → `toJson` → `fromJson` | Compare fields | All fields match original |

## 3. MediaFormat — Equality & HashCode

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-FMT-11 | `media_info.dart` | `operator ==` | Consider formats equal if `formatId` and `formatString` match | Two `MediaFormat` instances with identical IDs/Strings but different sizes | Compare with `==` | Returns `true` |
| U-DL-FMT-12 | `media_info.dart` | `operator ==` | Consider formats unequal if `formatId` differs | Two formats with different `formatId` but same `formatString` | Compare with `==` | Returns `false` |
| U-DL-FMT-13 | `media_info.dart` | `operator ==` | Consider formats unequal if `formatString` differs | Two formats with same `formatId` but different `formatString` | Compare with `==` | Returns `false` |
| U-DL-FMT-14 | `media_info.dart` | `operator ==` | Identity check | Same instance | Compare `identical(a, a)` via `==` | Returns `true` |
| U-DL-FMT-15 | `media_info.dart` | `hashCode` | Generate identical hash codes for equal objects | Two equal `MediaFormat` instances | Compare `.hashCode` | Hash codes match |
| U-DL-FMT-16 | `media_info.dart` | `hashCode` | Generate different hash codes for unequal objects | Two unequal `MediaFormat` instances | Compare `.hashCode` | Hash codes differ (best effort) |

## 4. MediaInfo — JSON Parsing (`fromJson`)

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-01 | `media_info.dart` | `MediaInfo.fromJson` | Parse complete standard yt-dlp metadata | Valid JSON map with `id`, `title`, `formats`, `duration` | Call `MediaInfo.fromJson` | Returns `MediaInfo` object with all fields correctly mapped |
| U-DL-MIN-02 | `media_info.dart` | `MediaInfo.fromJson` | Gracefully handle missing non-required fields | JSON map missing `filesize`, `thumbnail`, `duration` | Call `MediaInfo.fromJson` | Object created with missing fields set to `null` |
| U-DL-MIN-03 | `media_info.dart` | `MediaInfo.fromJson` | Use `originalUrl` parameter when `webpage_url` is absent | `originalUrl = 'https://example.com'`, JSON missing `webpage_url` | Call `MediaInfo.fromJson` | `originalUrl` equals `'https://example.com'` |
| U-DL-MIN-04 | `media_info.dart` | `MediaInfo.fromJson` | Fallback `originalUrl` to `webpage_url` from JSON | `originalUrl` is empty string, JSON contains `webpage_url` | Call `MediaInfo.fromJson` | `originalUrl` maps to `webpage_url` |
| U-DL-MIN-05 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle empty formats list | JSON map with `formats: []` | Call `MediaInfo.fromJson` | `formats` is empty list, no crash |
| U-DL-MIN-06 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle null formats list | JSON map with `formats: null` | Call `MediaInfo.fromJson` | `formats` is empty list, no crash |
| U-DL-MIN-07 | `media_info.dart` | `MediaInfo.fromJson` | Parse `filesize` fallback chain | JSON with `filesize: null`, `filesize_approx: null`, `file_size: null`, `size: 999` | Call `MediaInfo.fromJson` | `filesize` equals `999` |
| U-DL-MIN-08 | `media_info.dart` | `MediaInfo.fromJson` | Parse `isLive` flag | JSON with `is_live: true` | Call `MediaInfo.fromJson` | `isLive` is `true` |

## 5. MediaInfo — Title Parsing & Fallbacks

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-09 | `media_info.dart` | `MediaInfo.fromJson` | Use JSON `title` field directly | JSON with `title: 'My Video'` | Call `MediaInfo.fromJson` | `title` is `'My Video'` |
| U-DL-MIN-10 | `media_info.dart` | `MediaInfo.fromJson` | Extract path segment from URL when title is empty | JSON with `title: ''`, `originalUrl = 'https://example.com/my-page/file'` | Call `MediaInfo.fromJson` | `title` is `'my-page'` (first non-empty path segment) |
| U-DL-MIN-11 | `media_info.dart` | `MediaInfo.fromJson` | Prepend `@` for Instagram/X/Twitter URLs | JSON with `title: ''`, `originalUrl = 'https://instagram.com/johndoe'` | Call `MediaInfo.fromJson` | `title` is `'@johndoe'` |
| U-DL-MIN-12 | `media_info.dart` | `MediaInfo.fromJson` | Fallback to "Unknown Playlist" for playlists | JSON with `title: ''`, empty `originalUrl`, `_type: 'playlist'` | Call `MediaInfo.fromJson` | `title` is `'Unknown Playlist'` |
| U-DL-MIN-13 | `media_info.dart` | `MediaInfo.fromJson` | Fallback to "Unknown Title" for singles | JSON with `title: ''`, empty `originalUrl`, no `_type` | Call `MediaInfo.fromJson` | `title` is `'Unknown Title'` |
| U-DL-MIN-14 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle unparseable URL in title fallback | JSON with `title: ''`, `originalUrl = ':::invalid'` | Call `MediaInfo.fromJson` | Falls through `try-catch`, uses `'Unknown Title'` |

## 6. MediaInfo — isVideo Detection

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-15 | `media_info.dart` | `MediaInfo.fromJson` | Detect video from `vcodec` field | JSON with `vcodec: 'avc1'` | Call `MediaInfo.fromJson` | `isVideo` is `true` |
| U-DL-MIN-16 | `media_info.dart` | `MediaInfo.fromJson` | Detect non-video when `vcodec` is `'none'` | JSON with `vcodec: 'none'` | Call `MediaInfo.fromJson` | `isVideo` is `false` |
| U-DL-MIN-17 | `media_info.dart` | `MediaInfo.fromJson` | Default to video if formats exist but no vcodec | JSON without `vcodec`, with `formats: [...]` | Call `MediaInfo.fromJson` | `isVideo` is `true` |
| U-DL-MIN-18 | `media_info.dart` | `MediaInfo.fromJson` | Detect video from extension field | JSON without `vcodec` or `formats`, with `extension: 'mp4'` | Call `MediaInfo.fromJson` | `isVideo` is `true` |
| U-DL-MIN-19 | `media_info.dart` | `MediaInfo.fromJson` | Non-video extension | JSON without `vcodec` or `formats`, with `extension: 'jpg'` | Call `MediaInfo.fromJson` | `isVideo` is `false` |

## 7. MediaInfo — Playlist & Item Count

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-20 | `media_info.dart` | `MediaInfo.fromJson` | Detect playlist from `_type` field | JSON with `_type: 'playlist'` | Call `MediaInfo.fromJson` | `isPlaylist` is `true` |
| U-DL-MIN-21 | `media_info.dart` | `MediaInfo.fromJson` | Extract `itemCount` from `playlist_count` | JSON with `_type: 'playlist'`, `playlist_count: 25` | Call `MediaInfo.fromJson` | `itemCount` is `25` |
| U-DL-MIN-22 | `media_info.dart` | `MediaInfo.fromJson` | Extract `itemCount` from `entries` list length | JSON with `_type: 'playlist'`, `entries: [1, 2, 3]` | Call `MediaInfo.fromJson` | `itemCount` is `3` |
| U-DL-MIN-23 | `media_info.dart` | `MediaInfo.fromJson` | `itemCount` is null for non-playlists | JSON without `_type` or `playlist_count` | Call `MediaInfo.fromJson` | `itemCount` is `null` |

## 8. MediaInfo — Thumbnail Extraction

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-24 | `media_info.dart` | `MediaInfo.fromJson` | Extract thumbnail from direct field | JSON with `thumbnail: 'https://img.jpg'` | Call `MediaInfo.fromJson` | `thumbnail` is `'https://img.jpg'` |
| U-DL-MIN-25 | `media_info.dart` | `MediaInfo.fromJson` | Extract thumbnail from `thumbnails` list (last element) | JSON without `thumbnail`, with `thumbnails: [{'url': 'a'}, {'url': 'b'}]` | Call `MediaInfo.fromJson` | `thumbnail` is `'b'` |
| U-DL-MIN-26 | `media_info.dart` | `MediaInfo.fromJson` | **[EDGE]** Handle empty `thumbnails` list | JSON without `thumbnail`, with `thumbnails: []` | Call `MediaInfo.fromJson` | `thumbnail` is `null` |

## 9. MediaInfo — copyWith

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-27 | `media_info.dart` | `MediaInfo.copyWith` | Override single field | MediaInfo with `title: 'Old'` | Call `copyWith(title: 'New')` | New instance has `title: 'New'`, all other fields unchanged |
| U-DL-MIN-28 | `media_info.dart` | `MediaInfo.copyWith` | Override multiple fields | MediaInfo with defaults | Call `copyWith(isProfile: true, thumbnail: 'url', galleryIndex: 5)` | All 3 fields updated, rest unchanged |
| U-DL-MIN-29 | `media_info.dart` | `MediaInfo.copyWith` | No-arg call preserves all fields | MediaInfo with all fields set | Call `copyWith()` | Returned instance is field-identical to original |
| U-DL-MIN-30 | `media_info.dart` | `MediaInfo.copyWith` | Override `engineId` and `fetchLogs` | MediaInfo with `engineId: null` | Call `copyWith(engineId: 'gallery-dl', fetchLogs: 'log...')` | Fields updated |

## 10. MediaInfo — Map Serialization

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-MIN-31 | `media_info.dart` | `MediaInfo.toMap` | Serialize all fields including formats | MediaInfo with 2 formats and all fields | Call `toMap()` | Map contains all keys, `formats` is list of JSON maps |
| U-DL-MIN-32 | `media_info.dart` | `MediaInfo.toMap` | Omit null optional fields | MediaInfo with null `thumbnail`, `duration`, `directUrl` | Call `toMap()` | Map does not contain `thumbnail`, `duration`, `directUrl` keys |
| U-DL-MIN-33 | `media_info.dart` | `MediaInfo.toMap` | Conditionally include `isLive` only when true | MediaInfo with `isLive: false` | Call `toMap()` | Map does not contain `isLive` key |
| U-DL-MIN-34 | `media_info.dart` | `MediaInfo.fromMap` | Deserialize from Map with all fields | Map with all keys populated | Call `MediaInfo.fromMap(map)` | All fields match, `isError` parsed from map |
| U-DL-MIN-35 | `media_info.dart` | `MediaInfo.fromMap` / `toMap` | Round-trip serialization | Create MediaInfo → `toMap()` → `fromMap()` | Compare fields | All fields match original |
| U-DL-MIN-36 | `media_info.dart` | `MediaInfo.fromMap` | Default values for missing keys | Map with only `id` and `originalUrl` | Call `fromMap(map)` | `title` is `''`, `isVideo` is `true`, `formats` is `[]`, `isPlaylist` is `false` |

## 11. MediaGroup — Construction & Getters

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GRP-01 | `media_info.dart` | `MediaGroup.isSingle` | Return true if 1 item in group | `MediaGroup` with 1 item | Check `isSingle` | Returns `true` |
| U-DL-GRP-02 | `media_info.dart` | `MediaGroup.isSingle` | Return true if 0 items in group | `MediaGroup` with empty items | Check `isSingle` | Returns `true` |
| U-DL-GRP-03 | `media_info.dart` | `MediaGroup.isSingle` | Return false if 2+ items | `MediaGroup` with 3 items | Check `isSingle` | Returns `false` |
| U-DL-GRP-04 | `media_info.dart` | `MediaGroup.first` | Return first item | `MediaGroup` with 3 items | Check `first` | Returns the first item |
| U-DL-GRP-05 | `media_info.dart` | `MediaGroup.first` | **[EDGE]** Throw on empty items | `MediaGroup` with empty items | Check `first` | Throws `StateError` |
| U-DL-GRP-06 | `media_info.dart` | `MediaGroup.imageCount` & `videoCount` | Correctly count based on `isVideo` flags | `MediaGroup` with 2 videos, 3 images | Check `imageCount`, `videoCount` | `imageCount=3`, `videoCount=2` |

## 12. MediaGroup — Total Filesize Estimation

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GRP-07 | `media_info.dart` | `MediaGroup.totalFilesize` | Sum exact filesizes correctly if all have known sizes | Group with 2 items, sizes 10MB and 5MB | Check `totalFilesize` | Returns `15728640` (15MB in bytes) |
| U-DL-GRP-08 | `media_info.dart` | `MediaGroup.totalFilesize` | Estimate missing video sizes using average of known videos | Group: Vid A (10MB), Vid B (null) | Check `totalFilesize` | Uses average: 10 + 10 = 20MB |
| U-DL-GRP-09 | `media_info.dart` | `MediaGroup.totalFilesize` | Estimate missing image sizes using average of known images | Group: Img A (2MB), Img B (null) | Check `totalFilesize` | Uses average: 2 + 2 = 4MB |
| U-DL-GRP-10 | `media_info.dart` | `MediaGroup.totalFilesize` | Fallback to hardcoded video constant if NO videos have known sizes | Group: Vid A (null), Vid B (null) | Check `totalFilesize` | Each vid uses 15MB fallback → 30MB |
| U-DL-GRP-11 | `media_info.dart` | `MediaGroup.totalFilesize` | Fallback to hardcoded image constant if NO images have known sizes | Group: Img A (null), Img B (null) | Check `totalFilesize` | Each img uses 1MB fallback → 2MB |
| U-DL-GRP-12 | `media_info.dart` | `MediaGroup.totalFilesize` | Mixed video + image with mixed known/unknown sizes | Group: Vid(10MB), Vid(null), Img(2MB), Img(null) | Check `totalFilesize` | Vid: 10+10=20MB, Img: 2+2=4MB → 24MB total |
| U-DL-GRP-13 | `media_info.dart` | `MediaGroup.totalFilesize` | Exclude error items from total size | `MediaGroup` with 2 items (size: 100 valid, size: 200 with `isError=true`) | Evaluate `totalFilesize` | Items with `isError=true` still counted (no error exclusion in implementation) |
| U-DL-GRP-14 | `media_info.dart` | `MediaGroup.totalFilesize` | **[EDGE]** Empty group total size | `MediaGroup` with 0 items | Evaluate `totalFilesize` | Returns `0` |
| U-DL-GRP-15 | `media_info.dart` | `MediaGroup.totalFilesize` | **[EDGE]** Sum massive filesizes | `MediaGroup` with 3 items of 5GB each | Evaluate `totalFilesize` | Returns `15000000000` (no int overflow) |

## 13. MediaGroup — Map Serialization

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GRP-16 | `media_info.dart` | `MediaGroup.toMap` | Serialize group with items | Group with 2 items | Call `toMap()` | Map contains `originalUrl` and `items` list of 2 maps |
| U-DL-GRP-17 | `media_info.dart` | `MediaGroup.fromMap` | Deserialize group from Map | Map with `originalUrl` and `items` list | Call `fromMap(map)` | Group has correct URL and item count |
| U-DL-GRP-18 | `media_info.dart` | `MediaGroup.fromMap` / `toMap` | Round-trip serialization | Create group → `toMap()` → `fromMap()` | Compare fields | All fields match original |
| U-DL-GRP-19 | `media_info.dart` | `MediaGroup.fromMap` | **[EDGE]** Missing items key | Map with only `originalUrl` | Call `fromMap(map)` | `items` is empty list |
