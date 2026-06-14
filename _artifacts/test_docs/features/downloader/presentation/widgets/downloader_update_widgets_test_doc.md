# Downloader Update Widgets Unit Test Plan

**Files Under Test:** 
- `lib/features/downloader/presentation/widgets/downloader_update_banner.dart`
- `lib/features/downloader/presentation/widgets/downloader_update_dialog.dart`
**Target Layer:** Presentation / UI
**Coverage Target:** >90%

## 1. Downloader Update Banner (`downloader_update_banner.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-UPD-01 | `downloader_update_banner.dart` | `DownloaderUpdateBanner` | Hide banner when no updates required | `requiredInstalled = true`, no updates available | Render Widget | Returns `SizedBox.shrink()` |
| W-DL-UPD-02 | `downloader_update_banner.dart` | `DownloaderUpdateBanner` | Show critical banner when required engines missing | `EngineRegistry.missingRequired` is non-empty | Render Widget | Banner shows red background, "Required components missing" text |
| W-DL-UPD-03 | `downloader_update_banner.dart` | `DownloaderUpdateBanner` | Trigger install dialog | Missing engines banner active | Tap "Install Now" | Shows `DownloaderUpdateDialog` |
| W-DL-UPD-04 | `downloader_update_banner.dart` | `DownloaderUpdateBanner` | Show update banner when newer versions available | `downloaderUpdateProvider` state has `latestVersions` > `installedVersions` | Render Widget | Shows blue banner, "Updates available" text |
| W-DL-UPD-05 | `downloader_update_banner.dart` | `DownloaderUpdateBanner` | Trigger global update from banner | Update banner active | Tap "Update All" | Calls `downloaderUpdateProvider.updateAll()` |

## 2. Downloader Update Dialog (`downloader_update_dialog.dart`)

| Test ID | File(s) Under Test | Target Widget / Logic | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-UPD-06 | `downloader_update_dialog.dart` | `DownloaderUpdateDialog` | Render required engines list | Missing engines detected | Render Widget | Dialog shows list of missing required engines |
| W-DL-UPD-07 | `downloader_update_dialog.dart` | `DownloaderUpdateDialog` | Show global progress bar | `downloaderUpdateProvider.isUpdating = true`, progress `0.5` | Render Widget | Main progress bar is visible and at 50% |
| W-DL-UPD-08 | `downloader_update_dialog.dart` | `DownloaderUpdateDialog` | Disable close button while updating | `isUpdating = true` | Check dialog UI | Close/Cancel button is disabled |
| W-DL-UPD-09 | `downloader_update_dialog.dart` | `DownloaderUpdateDialog` | Show error state | Update provider throws error | Check state | Dialog shows red error text with retry button |
| W-DL-UPD-10 | `downloader_update_dialog.dart` | `DownloaderUpdateDialog` | Automatically close on success | Missing engines were installed | Wait for `isUpdating` to become false | Dialog dismisses via `Navigator.pop` |
