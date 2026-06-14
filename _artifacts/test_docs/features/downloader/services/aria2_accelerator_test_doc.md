# Aria2Accelerator Unit Test Plan

**File Under Test:** `lib/features/downloader/services/aria2_accelerator.dart`
**Target Layer:** Services
**Coverage Target:** 100%

## 1. Binary Path Resolution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-01 | `aria2_accelerator.dart` | `binaryPath` | Resolve to bundled binary path under HOME | Mock `HOME` environment variable | Check `binaryPath` | Returns `$HOME/.local/share/onyxcore/bin/aria2c` |
| U-DL-AR2-02 | `aria2_accelerator.dart` | `binaryPath` | **[EDGE]** Handle empty HOME variable | `HOME` is empty string | Check `binaryPath` | Returns path starting with `/.local/share/...` (no crash) |

## 2. Availability & Caching

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-03 | `aria2_accelerator.dart` | `isAvailable` | Prefer bundled binary | Mock filesystem with `~/.local/share/onyxcore/bin/aria2c` existing | Check `isAvailable` | Returns `true`, caches result |
| U-DL-AR2-04 | `aria2_accelerator.dart` | `isAvailable` | Fallback to system binary if bundled is missing | Mock filesystem without bundled binary, mock `Process.runSync('which')` returns 0 | Check `isAvailable` | Returns `true` |
| U-DL-AR2-05 | `aria2_accelerator.dart` | `isAvailable` | Return false if completely missing | Mock missing bundled and system binaries | Check `isAvailable` | Returns `false` |
| U-DL-AR2-06 | `aria2_accelerator.dart` | `isAvailable` | Return cached result on subsequent calls | Previous call returned `true` | Call `isAvailable` again | Returns `true` without re-checking filesystem |
| U-DL-AR2-07 | `aria2_accelerator.dart` | `isAvailable` | **[EDGE]** `which` command throws exception | Mock `Process.runSync` throwing | Check `isAvailable` | Returns `false`, catches exception |

## 3. Executable Resolution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-08 | `aria2_accelerator.dart` | `executable` | Return absolute path when bundled binary exists | Mock bundled binary exists | Check `executable` | Returns full absolute path to bundled binary |
| U-DL-AR2-09 | `aria2_accelerator.dart` | `executable` | Return `'aria2c'` string when bundled binary missing | Mock bundled binary absent | Check `executable` | Returns `'aria2c'` (system fallback) |

## 4. Cache Reset

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-10 | `aria2_accelerator.dart` | `resetCache` | Clear cached availability | `_available` was `true` | Call `resetCache()` | Next `isAvailable` call re-evaluates from filesystem |

## 5. Download Process Arguments

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-11 | `aria2_accelerator.dart` | `download` | Construct precise aria2c CLI args with filename | `url = 'xyz'`, `destination = '/tmp'`, `filename = 'test.mp4'` | Call `download` | Args include `-x 16`, `-s 16`, `-k 1M`, `-d /tmp`, `--out test.mp4`, `--summary-interval=1`, `--console-log-level=notice`, URL |
| U-DL-AR2-12 | `aria2_accelerator.dart` | `download` | Omit `--out` flag when filename is null | `filename = null` | Call `download` | Args do NOT include `--out` |
| U-DL-AR2-13 | `aria2_accelerator.dart` | `download` | Accept custom connections and splits | `connections = 8`, `splits = 8`, `minSplitSize = '2M'` | Call `download` | Args include `-x 8`, `-s 8`, `-k 2M` |

## 6. Downloader Args String

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-14 | `aria2_accelerator.dart` | `downloaderArgs` | Provide standardized args string for engines | - | Check `downloaderArgs` | Returns exact string `'aria2c:-x 16 -s 16 -k 1M --summary-interval=1'` |
