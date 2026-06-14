# DownloadHistoryDatabase Unit Test Plan

**File Under Test:** `lib/features/downloader/services/download_history_database.dart`
**Target Layer:** Services
**Coverage Target:** >95%

## 1. Initialization & Schema

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-01 | `download_history_database.dart` | `init` | Create SQLite database file and parent dirs if missing | Mock filesystem without `.sqlite` file or parent directory | Call `init` | Database file is created, schema initialized with `history` table |
| U-DL-HDB-02 | `download_history_database.dart` | `init` | Open existing database without recreating | Mock filesystem with existing `.sqlite` file | Call `init` | Database opens successfully, existing data preserved |

## 2. Legacy JSON Migration

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-03 | `download_history_database.dart` | `_migrateLegacyData` | Migrate data from JSON file if exists | Mock filesystem containing `download_history.json` with 2 valid entries | Call `init` (which triggers migration) | Database contains 2 rows, JSON file renamed to `.migrated` |
| U-DL-HDB-04 | `download_history_database.dart` | `_migrateLegacyData` | Gracefully handle corrupt JSON file | Mock filesystem with malformed JSON content | Call `init` | Does not crash, continues initialization, database is empty |
| U-DL-HDB-05 | `download_history_database.dart` | `_migrateLegacyData` | No-op when legacy file does not exist | Mock filesystem without `download_history.json` | Call `init` | No error, migration skipped |
| U-DL-HDB-06 | `download_history_database.dart` | `_migrateLegacyData` | Use `INSERT OR IGNORE` to skip duplicates | Legacy JSON has entries with IDs already in DB | Call `init` | No duplicate rows created |

## 3. Insert & Upsert

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-07 | `download_history_database.dart` | `insertEntry` | Insert new entry successfully | Initialized empty DB, `DownloadHistoryEntry` object | Call `insertEntry` | Row inserted, retrievable via `getEntry` |
| U-DL-HDB-08 | `download_history_database.dart` | `insertEntry` | Update existing entry via UPSERT (`INSERT OR REPLACE`) | DB containing entry with ID '1', `statusName='pending'` | Call `insertEntry` with ID '1', `statusName='completed'` | `getEntry('1')` returns status 'completed' |
| U-DL-HDB-09 | `download_history_database.dart` | `insertEntry` | Serialize logs list as JSON | Entry with `logs = ['line1', 'line2']` | Call `insertEntry`, then `getEntry` | Retrieved entry `logs` is `['line1', 'line2']` |
| U-DL-HDB-10 | `download_history_database.dart` | `insertEntry` | Handle null `completedAt` | Entry with `completedAt = null` | Call `insertEntry`, then `getEntry` | Retrieved entry `completedAt` is `null` |

## 4. Read Operations

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-11 | `download_history_database.dart` | `getEntries` | Return entries ordered by `createdAt DESC` | DB with entries created at different times | Call `getEntries()` | Most recent entry is first |
| U-DL-HDB-12 | `download_history_database.dart` | `getEntries` | Respect pagination limits and offsets | DB with 10 entries | Call `getEntries(limit: 5, offset: 2)` | Returns 5 entries starting from the 3rd most recent |
| U-DL-HDB-13 | `download_history_database.dart` | `getEntries` | Return empty list for empty DB | Empty DB | Call `getEntries()` | Returns `[]` |
| U-DL-HDB-14 | `download_history_database.dart` | `getTotalCount` | Accurately count rows | DB with 4 entries | Call `getTotalCount` | Returns `4` |
| U-DL-HDB-15 | `download_history_database.dart` | `getTotalCount` | Return 0 for empty DB | Empty DB | Call `getTotalCount` | Returns `0` |
| U-DL-HDB-16 | `download_history_database.dart` | `getEntry` | Return entry by ID | DB containing entry with ID 'abc' | Call `getEntry('abc')` | Returns matching `DownloadHistoryEntry` |
| U-DL-HDB-17 | `download_history_database.dart` | `getEntry` | Return null for non-existent ID | DB without ID 'xyz' | Call `getEntry('xyz')` | Returns `null` |

## 5. Delete Operations

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-18 | `download_history_database.dart` | `deleteEntries` | Delete specific rows by IDs | DB with IDs 'A', 'B', 'C' | Call `deleteEntries({'A', 'C'})` | 'A' and 'C' removed, 'B' remains |
| U-DL-HDB-19 | `download_history_database.dart` | `deleteEntries` | No-op for empty set | Populated DB | Call `deleteEntries({})` | No rows deleted, all remain |
| U-DL-HDB-20 | `download_history_database.dart` | `clearAll` | Truncate and vacuum database | Populated DB with 5 entries | Call `clearAll` | `getTotalCount` returns 0 |

## 6. File Size & Disposal

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-21 | `download_history_database.dart` | `fileSize` | Return DB file size in bytes | DB file exists with data | Check `fileSize` | Returns positive integer |
| U-DL-HDB-22 | `download_history_database.dart` | `fileSize` | Return 0 when DB file doesn't exist | DB file path invalid | Check `fileSize` | Returns `0` |
| U-DL-HDB-23 | `download_history_database.dart` | `dispose` | Close database without crash | Initialized DB | Call `dispose` | No exception thrown |

## 7. Internal Row Parsing

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-HDB-24 | `download_history_database.dart` | `_entryFromRow` | Correctly deserialize all fields from DB row | Row with all columns populated | Insert and retrieve entry | All fields match: `id`, `title`, `statusName`, `downloadType`, `errorMessage`, `url`, `destination`, `logs`, `createdAt`, `completedAt` |
| U-DL-HDB-25 | `download_history_database.dart` | `_entryFromRow` | Handle null `completedAt` column | Row with `completedAt = null` | Retrieve entry | `completedAt` is `null` |
| U-DL-HDB-26 | `download_history_database.dart` | `_entryFromRow` | Handle null `errorMessage` column | Row with `errorMessage = null` | Retrieve entry | `errorMessage` is `null` |
