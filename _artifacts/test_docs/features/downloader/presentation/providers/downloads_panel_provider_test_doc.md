# DownloadsPanelProvider Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/providers/downloads_panel_provider.dart`
**Target Layer:** Presentation / Providers
**Coverage Target:** 100%

## 1. Local UI State & Hive Integration

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-PNL-01 | `downloads_panel_provider.dart` | `DownloadsPanelWidthNotifier` | Read initial width from Hive | Mock Hive box containing `side_panel_width_pixels=400` | Initialize Provider | State is `400.0` |
| U-DL-PNL-02 | `downloads_panel_provider.dart` | `DownloadsPanelWidthNotifier` | Save new width to Hive | Provider initialized | Call `updateWidth(350.0)` | State is `350.0`, value written to Hive |
| U-DL-PNL-03 | `downloads_panel_provider.dart` | `DownloadsListCache` | Clear cache correctly | Cache has items and configs | Call `clear()` | Properties reset to null/empty |
