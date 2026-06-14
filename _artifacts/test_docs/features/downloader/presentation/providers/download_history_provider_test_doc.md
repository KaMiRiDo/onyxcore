# DownloadHistoryProvider Unit Test Plan

**File Under Test:** `lib/features/downloader/presentation/providers/download_history_provider.dart`
**Target Layer:** Presentation / Providers
**Coverage Target:** >90%

## 1. DownloadHistoryEntry Entity

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-01 | `download_history_provider.dart` | `DownloadHistoryEntry()` | Create with all required fields | All fields provided | Construct entry | All fields match provided values |
| U-DL-HST-02 | `download_history_provider.dart` | `DownloadHistoryEntry()` | Use default values for optional fields | Only required fields | Construct entry | `downloadType='generic'`, `logs=[]`, `completedAt=null`, `errorMessage=null` |
| U-DL-HST-03 | `download_history_provider.dart` | `DownloadHistoryEntry.fromTask` | Map all DownloadTask fields correctly | `DownloadTask` with all fields populated | Call `fromTask` | All fields match: `id`, `title`, `status.name`, `downloadType`, `error`, `url`, `destination`, `logs`, `createdAt`, `completedAt` |
| U-DL-HST-04 | `download_history_provider.dart` | `DownloadHistoryEntry.fromJson` | Parse JSON with all fields | JSON map with all keys | Call `fromJson` | All fields correctly mapped |
| U-DL-HST-05 | `download_history_provider.dart` | `DownloadHistoryEntry.fromJson` | Handle missing/null fields gracefully | JSON with only `id` | Call `fromJson` | `title='Untitled Download'`, `statusName='completed'`, `url=''`, `logs=[]`, `createdAt=DateTime.now()` |
| U-DL-HST-06 | `download_history_provider.dart` | `DownloadHistoryEntry.toJson` | Serialize all fields to JSON | Entry with all fields | Call `toJson()` | Map contains all keys including `createdAt` as ISO string |
| U-DL-HST-07 | `download_history_provider.dart` | `DownloadHistoryEntry.toJson` / `fromJson` | Round-trip serialization | Create entry → `toJson` → `fromJson` | Compare fields | All fields match original |
| U-DL-HST-08 | `download_history_provider.dart` | `duration` getter | Return correct duration when completedAt is set | `createdAt` = 10:00, `completedAt` = 10:05 | Check `duration` | Returns `Duration(minutes: 5)` |
| U-DL-HST-09 | `download_history_provider.dart` | `duration` getter | Return null when completedAt is null | `completedAt = null` | Check `duration` | Returns `null` |

## 2. DownloadHistoryNotifier — Pagination

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-10 | `download_history_provider.dart` | `build` | Load initial page of 50 results | Mock DB with 100 entries | Initialize Provider | State length is 50, `hasMore` is true |
| U-DL-HST-11 | `download_history_provider.dart` | `loadMore` | Load subsequent page | Provider initialized with 50 loaded | Call `loadMore` | State length increases (up to 100) |
| U-DL-HST-12 | `download_history_provider.dart` | `loadMore` | **[EDGE]** No-op when no more entries | All entries already loaded (`hasMore=false`) | Call `loadMore` | State unchanged |
| U-DL-HST-13 | `download_history_provider.dart` | `hasMore` | Return false when all entries loaded | DB has 30 entries, all loaded | Check `hasMore` | Returns `false` |
| U-DL-HST-14 | `download_history_provider.dart` | `totalEntries` | Return total count from DB | DB has 150 entries | Check `totalEntries` | Returns `150` |

## 3. DownloadHistoryNotifier — Mutations

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-15 | `download_history_provider.dart` | `addEntry` | Prepend new entry to state | Mock DB with 10 entries | Call `addEntry(task)` | State length is 11, new entry is at index 0 |
| U-DL-HST-16 | `download_history_provider.dart` | `addEntry` | Insert into DB | - | Call `addEntry(task)` | `_db.insertEntry` called |
| U-DL-HST-17 | `download_history_provider.dart` | `deleteEntries` | Remove multiple entries by IDs | State with IDs 'A', 'B', 'C' | Call `deleteEntries({'A', 'C'})` | State contains only 'B', `_loadedCount` decremented by 2 |
| U-DL-HST-18 | `download_history_provider.dart` | `deleteEntry` | Remove single entry by ID | State with IDs 'A', 'B' | Call `deleteEntry('A')` | State contains only 'B' |
| U-DL-HST-19 | `download_history_provider.dart` | `deleteEntries` | **[EDGE]** `_loadedCount` clamps to 0 | `_loadedCount` is 1, deleting 5 entries | Call `deleteEntries` | `_loadedCount` is 0, not negative |
| U-DL-HST-20 | `download_history_provider.dart` | `clearAll` | Reset state and counters | Populated state | Call `clearAll` | State is `[]`, `_loadedCount` is 0 |
| U-DL-HST-21 | `download_history_provider.dart` | `getEntry` | Retrieve specific entry from DB | DB contains entry with ID 'abc' | Call `getEntry('abc')` | Returns matching entry |
| U-DL-HST-22 | `download_history_provider.dart` | `historyFileSize` | Return DB file size | DB exists | Check `historyFileSize` | Returns positive integer |

## 4. DownloadHistoryNotifier — Filtered Deletion

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-23 | `download_history_provider.dart` | `deleteFiltered` | Delete all items matching filter | State has 'completed' and 'error' items, filter status='error' | Call `deleteFiltered(filter)` | Only 'error' items deleted |
| U-DL-HST-24 | `download_history_provider.dart` | `deleteFiltered` | Delete all items when filter is empty | Empty filter | Call `deleteFiltered(filter)` | All items deleted |

## 5. DownloadHistoryFilter

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-25 | `download_history_provider.dart` | `DownloadHistoryFilter.isEmpty` | Return true when no dates and status is null | Default filter | Check `isEmpty` | Returns `true` |
| U-DL-HST-26 | `download_history_provider.dart` | `DownloadHistoryFilter.isEmpty` | Return true when status is 'All' | `status = 'All'` | Check `isEmpty` | Returns `true` |
| U-DL-HST-27 | `download_history_provider.dart` | `DownloadHistoryFilter.isEmpty` | Return false when selectedDates is non-empty | `selectedDates = {DateTime.now()}` | Check `isEmpty` | Returns `false` |
| U-DL-HST-28 | `download_history_provider.dart` | `DownloadHistoryFilter.isEmpty` | Return false when status is specific | `status = 'error'` | Check `isEmpty` | Returns `false` |
| U-DL-HST-29 | `download_history_provider.dart` | `DownloadHistoryFilter.copyWith` | Override specific fields | Filter with `status='All'` | Call `copyWith(status: 'error')` | `status` is `'error'`, `selectedDates` unchanged |
| U-DL-HST-30 | `download_history_provider.dart` | `_matchesFilter` | Match by date | Filter with today's date, entry from today | Check `_matchesFilter` | Returns `true` |
| U-DL-HST-31 | `download_history_provider.dart` | `_matchesFilter` | Match by status (case-insensitive) | Filter with `status='Completed'`, entry with `statusName='completed'` | Check `_matchesFilter` | Returns `true` |
| U-DL-HST-32 | `download_history_provider.dart` | `_matchesFilter` | **[EDGE]** Combined filter — both date and status must match | Filter with today + 'error', entry is today + 'completed' | Check `_matchesFilter` | Returns `false` |

## 6. Derived Providers

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-33 | `download_history_provider.dart` | `filteredDownloadHistoryProvider` | Return full list when filter is empty | Empty filter, 10 history items | Watch provider | Returns all 10 items |
| U-DL-HST-34 | `download_history_provider.dart` | `filteredDownloadHistoryProvider` | Filter by status | Filter status = 'error', 3 error + 7 completed | Watch provider | Returns 3 items |
| U-DL-HST-35 | `download_history_provider.dart` | `availableDownloadDatesProvider` | Extract unique dates from history | History with items from 3 different dates | Watch provider | Returns set with 3 dates |
| U-DL-HST-36 | `download_history_provider.dart` | `downloadHistoryFilterProvider` | Default to empty filter | - | Watch provider | Returns `DownloadHistoryFilter()` with `isEmpty=true` |

## 7. DownloadHistorySelectionNotifier

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HST-37 | `download_history_provider.dart` | `build` | Initialize with empty set | - | Initialize | State is `{}` |
| U-DL-HST-38 | `download_history_provider.dart` | `toggle` | Add item to selection | Empty selection | Call `toggle('1')` | State contains `'1'` |
| U-DL-HST-39 | `download_history_provider.dart` | `toggle` | Remove item from selection | Selection contains `'1'` | Call `toggle('1')` | State is empty |
| U-DL-HST-40 | `download_history_provider.dart` | `toggle` | Set anchor to toggled item | Empty selection | Call `toggle('A')` | `_lastSelectedId` is `'A'` |
| U-DL-HST-41 | `download_history_provider.dart` | `toggle` | Clear anchor when item removed | Selection `{'A'}` | Call `toggle('A')` | `_lastSelectedId` is `null` |
| U-DL-HST-42 | `download_history_provider.dart` | `setAnchor` | Set last selected ID | - | Call `setAnchor('X')` | `_lastSelectedId` is `'X'` |
| U-DL-HST-43 | `download_history_provider.dart` | `selectRange` | Select range from anchor to target | Entries A,B,C,D. Anchor='A' | Call `selectRange(entries, 'D')` | State contains `{A, B, C, D}` |
| U-DL-HST-44 | `download_history_provider.dart` | `selectRange` | Fallback to toggle when no anchor | `_lastSelectedId = null` | Call `selectRange(entries, 'B')` | State contains `{'B'}` |
| U-DL-HST-45 | `download_history_provider.dart` | `selectRange` | **[EDGE]** Fallback to toggle when ID not found | `_lastSelectedId='Z'` (not in entries) | Call `selectRange(entries, 'B')` | State contains `{'B'}` |
| U-DL-HST-46 | `download_history_provider.dart` | `selectRange` | Handle reverse range (target before anchor) | Entries A,B,C,D. Anchor='D' | Call `selectRange(entries, 'A')` | State contains `{A, B, C, D}` |
| U-DL-HST-47 | `download_history_provider.dart` | `clear` | Reset selection and anchor | Selection `{'A', 'B'}` | Call `clear()` | State is `{}`, `_lastSelectedId` is `null` |
