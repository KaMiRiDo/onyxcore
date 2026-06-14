# GalleryDlEngine Unit Test Plan

**File Under Test:** `lib/features/downloader/services/engines/gallery_dl_engine.dart`
**Target Layer:** Services / Engines
**Coverage Target:** >90%

## 1. Social Profile Detection

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GAL-01 | `gallery_dl_engine.dart` | `_isSocialProfile` | Detect Instagram profile vs post | URL = `https://instagram.com/user` | Evaluate `_isSocialProfile` | Returns `true` |
| U-DL-GAL-02 | `gallery_dl_engine.dart` | `_isSocialProfile` | Detect Instagram post | URL = `https://instagram.com/p/1234` | Evaluate `_isSocialProfile` | Returns `false` |
| U-DL-GAL-03 | `gallery_dl_engine.dart` | `_isSocialProfile` | Detect Twitter/X profile | URL = `https://x.com/user` | Evaluate `_isSocialProfile` | Returns `true` |
| U-DL-GAL-04 | `gallery_dl_engine.dart` | `_isSocialProfile` | Detect Reddit subreddit vs post | URL = `https://reddit.com/r/pics` | Evaluate `_isSocialProfile` | Returns `true` |

## 2. Fast Instagram Profile Fetching

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GAL-05 | `gallery_dl_engine.dart` | `_fetchInstagramProfile` | Parse Instagram API JSON directly | Mock `HttpClient` returning valid Instagram API JSON | Call `_fetchInstagramProfile` | Returns `MediaInfo` list with profile info and extracted posts |
| U-DL-GAL-06 | `gallery_dl_engine.dart` | `_fetchInstagramProfile` | Fallback to gallery-dl if API request fails | Mock `HttpClient` returning `404` or throwing Exception | Call `_fetchInstagramProfile` | Returns `null`, allowing engine to fallback to CLI |
| U-DL-GAL-07 | `gallery_dl_engine.dart` | `_fetchInstagramProfile` | Pass cookies to the request | Mock `CookieHelper.extractCookies` | Call `_fetchInstagramProfile` | HTTP Request headers contain `Cookie` string |

## 3. Streaming JSON State Machine

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GAL-08 | `gallery_dl_engine.dart` | `fetchMetadata` | Parse chunked JSON stdout streams correctly | Mock `Process.stdout` emitting fragmented JSON bytes | Call `fetchMetadata` | State machine reconstructs JSON correctly without parser crash |
| U-DL-GAL-09 | `gallery_dl_engine.dart` | `fetchMetadata` | Ignore whitespace and tracking pixels | Mock `Process.stdout` with leading tabs and spaces | Call `fetchMetadata` | Skips whitespace and begins parsing at `[` or `{` |
| U-DL-GAL-10 | `gallery_dl_engine.dart` | `fetchMetadata` | **[EDGE]** JSON boundaries split across stream chunks | Output chunk 1 ends with `{"titl`, chunk 2 begins with `e": "test"}` | Call `fetchMetadata` | Reconstructs without failure |
| U-DL-GAL-11 | `gallery_dl_engine.dart` | `fetchMetadata` | **[EDGE]** Escape characters interrupting chunking | Chunk ends with `\\\\` before `"` | Call `fetchMetadata` | Machine handles escape logic correctly |

## 4. JSON Block Parsing — File Events

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GAL-12 | `gallery_dl_engine.dart` | `_parseGalleryDlJsonBlock` | Extract valid file events (Type 3) | Mock gallery-dl output where event type is `3` | Call `fetchMetadata` | Appends new `MediaInfo` for the file |
| U-DL-GAL-13 | `gallery_dl_engine.dart` | `_parseGalleryDlJsonBlock` | Deduplicate identical file URLs | Output contains two events pointing to same `.jpg` | Parse block | Only one format is added to the results |

## 5. Platform-Specific Title & Thumbnail Extraction

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GAL-14 | `gallery_dl_engine.dart` | `_parseGalleryDlJsonBlock` | Extract Reddit titles with Subreddit prefix | JSON contains `subreddit: 'pics'` and `title: 'Cat'` | Parse block | Title is `r/pics - Cat (@unknown)` |
| U-DL-GAL-15 | `gallery_dl_engine.dart` | `_parseGalleryDlJsonBlock` | Extract Twitter/X item URLs correctly | JSON contains `tweet_id: '123'` | Parse block | `originalUrl` points to `status/123` |
| U-DL-GAL-16 | `gallery_dl_engine.dart` | `_parseGalleryDlJsonBlock` | Extract video URLs from Reddit secure_media | JSON contains `secure_media.reddit_video.fallback_url` | Parse block | `fileUrl` is the fallback URL, `isVideo` is true |

## 6. Download Execution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-GAL-17 | `gallery_dl_engine.dart` | `startDownload` | Filter for images only | `filterType: 'images'` | Call `startDownload` | Args include `--filter extension not in ('mp4', ...)` |
| U-DL-GAL-18 | `gallery_dl_engine.dart` | `startDownload` | Filter for videos only | `filterType: 'videos'` | Call `startDownload` | Args include `--filter extension in ('mp4', ...)` |
| U-DL-GAL-19 | `gallery_dl_engine.dart` | `startDownload` | Download specific gallery index | `galleryIndex: 3` | Call `startDownload` | Args include `--range 3` and precise filename |
| U-DL-GAL-20 | `gallery_dl_engine.dart` | `startDownload` | Avoid profile folder generation | `title='My Download'` | Call `startDownload` | Args include `-o directory=[]` to force base destination |
