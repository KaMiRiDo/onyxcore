# DownloadHistoryDatabase Unit Test Plan

**File Under Test:** `lib/features/downloader/services/download_history_database.dart`
**Target Layer:** Services
**Coverage Target:** >95%

## 1. Initialization & Migration

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-01 | `download_history_database.dart` | `init` | Create SQLite database file if missing | Mock filesystem without `.sqlite` file | Call `init` | Database file is created, schema initialized |
| U-DL-HDB-02 | `download_history_database.dart` | `_migrateLegacyData` | Migrate data from JSON file if exists | Mock filesystem containing `download_history.json` with 2 valid entries | Call `init` (which triggers migration) | Database contains 2 rows, JSON file renamed to `.migrated` |
| U-DL-HDB-03 | `download_history_database.dart` | `_migrateLegacyData` | Gracefully handle corrupt JSON file | Mock filesystem with malformed JSON | Call `init` | Does not crash, continues initialization |

## 2. CRUD Operations

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-04 | `download_history_database.dart` | `insertEntry` | Insert new entry successfully | Initialized empty DB, `DownloadHistoryEntry` object | Call `insertEntry` | Row inserted, retrievable via `getEntry` |
| U-DL-HDB-05 | `download_history_database.dart` | `insertEntry` | Update existing entry via UPSERT | DB containing entry with ID '1', `statusName='pending'` | Call `insertEntry` with ID '1', `statusName='completed'` | `getEntry('1')` returns status 'completed' |
| U-DL-HDB-06 | `download_history_database.dart` | `getEntries` | Respect pagination limits and offsets | DB with 10 entries | Call `getEntries(limit: 5, offset: 2)` | Returns 5 entries starting from the 3rd most recent |
| U-DL-HDB-07 | `download_history_database.dart` | `getTotalCount` | Accurately count rows | DB with 4 entries | Call `getTotalCount` | Returns 4 |
| U-DL-HDB-08 | `download_history_database.dart` | `deleteEntries` | Delete specific rows | DB with IDs 'A', 'B', 'C' | Call `deleteEntries({'A', 'C'})` | 'A' and 'C' removed, 'B' remains |
| U-DL-HDB-09 | `download_history_database.dart` | `clearAll` | Truncate and vacuum database | Populated DB | Call `clearAll` | `getTotalCount` returns 0, filesize potentially drops |
