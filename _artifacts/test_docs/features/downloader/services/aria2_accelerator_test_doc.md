# Aria2Accelerator Unit Test Plan

**File Under Test:** `lib/features/downloader/services/aria2_accelerator.dart`
**Target Layer:** Services
**Coverage Target:** 100%

## 1. Availability & Resolution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-01 | `aria2_accelerator.dart` | `isAvailable` | Prefer bundled binary | Mock filesystem with `~/.local/share/onyxcore/bin/aria2c` | Check `isAvailable` | Returns `true`, caches result |
| U-DL-AR2-02 | `aria2_accelerator.dart` | `isAvailable` | Fallback to system binary if bundled is missing | Mock filesystem without bundled binary, mock `Process.runSync('which')` returns 0 | Check `isAvailable` | Returns `true` |
| U-DL-AR2-03 | `aria2_accelerator.dart` | `isAvailable` | Return false if completely missing | Mock missing bundled and system binaries | Check `isAvailable` | Returns `false` |
| U-DL-AR2-04 | `aria2_accelerator.dart` | `executable` | Return specific path vs command | Mock bundled binary exists | Check `executable` | Returns full absolute path |

## 2. Process Execution

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-AR2-05 | `aria2_accelerator.dart` | `download` | Construct precise aria2c CLI args | `url = 'xyz'`, `destination = '/tmp'`, `filename = 'test.mp4'` | Call `download` | Args include `-x 16`, `-s 16`, `-k 1M`, `-d /tmp`, `--out test.mp4` |
| U-DL-AR2-06 | `aria2_accelerator.dart` | `downloaderArgs` | Provide standardized args string for engines | - | Check `downloaderArgs` | Returns string matching `aria2c:-x 16 -s 16 -k 1M --summary-interval=1` |
