# CookieHelper Unit Test Plan

**File Under Test:** `lib/features/downloader/services/cookie_helper.dart`
**Target Layer:** Services
**Coverage Target:** >90%

## 1. Browser Validation & Early Rejection

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-01 | `cookie_helper.dart` | `extractCookies` | Return null for null browser | `browser = null` | Call `extractCookies` | Returns `null` immediately |
| U-DL-CKI-02 | `cookie_helper.dart` | `extractCookies` | Return null for 'None' browser | `browser = 'None'` | Call `extractCookies` | Returns `null` immediately |
| U-DL-CKI-03 | `cookie_helper.dart` | `extractCookies` | Return null for empty browser string | `browser = ''` | Call `extractCookies` | Returns `null` immediately |
| U-DL-CKI-04 | `cookie_helper.dart` | `extractCookies` | Reject Chromium-based browsers | `browser = 'Google Chrome'` | Call `extractCookies` | Returns `null` immediately |
| U-DL-CKI-05 | `cookie_helper.dart` | `extractCookies` | Reject other unsupported browsers | `browser = 'Safari'` | Call `extractCookies` | Returns `null` immediately |

## 2. Supported Browser Detection

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-06 | `cookie_helper.dart` | `extractCookies` | Accept Firefox (case-insensitive) | `browser = 'firefox'` | Call `extractCookies` | Proceeds past browser check (does not return null for browser) |
| U-DL-CKI-07 | `cookie_helper.dart` | `extractCookies` | Accept LibreWolf | `browser = 'LibreWolf'` | Call `extractCookies` | Proceeds past browser check |
| U-DL-CKI-08 | `cookie_helper.dart` | `extractCookies` | Accept Waterfox | `browser = 'Waterfox'` | Call `extractCookies` | Proceeds past browser check |

## 3. Cookie Caching & TTL

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-09 | `cookie_helper.dart` | `extractCookies` | Return cached cookies if within TTL | Mock previous extraction within 5 minutes | Call `extractCookies(browser: 'Firefox')` | Returns cached string without accessing disk |
| U-DL-CKI-10 | `cookie_helper.dart` | `extractCookies` | Invalidate cache after TTL (5 minutes) expires | Mock `_cookiesCachedAt` to 6 minutes ago | Call `extractCookies` | Re-reads from filesystem, updates cache |
| U-DL-CKI-11 | `cookie_helper.dart` | `extractCookies` | **[EDGE]** Stale cache cleared even if re-fetch fails | Cache expired, no cookie DB found on disk | Call `extractCookies` | Returns `null`, `_cachedCookies` is null |

## 4. Profile Discovery

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-12 | `cookie_helper.dart` | `extractCookies` | Search standard Firefox profile path | Mock `~/.mozilla/firefox/profile/cookies.sqlite` | Call `extractCookies(browser: 'Firefox')` | Finds and uses the DB file |
| U-DL-CKI-13 | `cookie_helper.dart` | `extractCookies` | Search Snap Firefox profile path | Mock `~/snap/firefox/common/.mozilla/firefox/profile/cookies.sqlite` | Call `extractCookies(browser: 'Firefox')` | Finds and uses the snap DB file |
| U-DL-CKI-14 | `cookie_helper.dart` | `extractCookies` | Search Flatpak Firefox profile path | Mock `~/.var/app/org.mozilla.firefox/.mozilla/firefox/profile/cookies.sqlite` | Call `extractCookies(browser: 'Firefox')` | Finds and uses the flatpak DB file |
| U-DL-CKI-15 | `cookie_helper.dart` | `extractCookies` | **[EDGE]** No profiles found in any path | Mock empty/missing directories | Call `extractCookies(browser: 'Firefox')` | Returns `null` |

## 5. SQLite Cookie Extraction

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-16 | `cookie_helper.dart` | `extractCookies` | Parse cookies with default Instagram/Facebook domain filter | Mock Firefox profile dir containing `cookies.sqlite` with 1 Instagram row | Call `extractCookies(browser: 'Firefox')` | Returns string `'cookieName=cookieValue'` |
| U-DL-CKI-17 | `cookie_helper.dart` | `extractCookies` | Parse cookies with custom domain filter | Mock DB with `twitter.com` cookies | Call `extractCookies(browser: 'Firefox', domain: "host LIKE '%twitter%'")` | Returns matching cookies |
| U-DL-CKI-18 | `cookie_helper.dart` | `extractCookies` | Join multiple cookies with `'; '` separator | Mock DB returning 3 rows | Call `extractCookies` | Returns `'a=1; b=2; c=3'` |
| U-DL-CKI-19 | `cookie_helper.dart` | `extractCookies` | **[EDGE]** Empty result set from SQLite | Mock DB with no matching domain rows | Call `extractCookies` | Returns empty string `''` (cookies.join) |

## 6. Error Handling & Cleanup

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-20 | `cookie_helper.dart` | `extractCookies` | Gracefully handle locked or corrupt databases | Mock locked `cookies.sqlite` | Call `extractCookies` | Returns `null`, cleans up temp files |
| U-DL-CKI-21 | `cookie_helper.dart` | `extractCookies` | **[EDGE]** Clean up temp file after exception | Mock exception during `sqlite3.open` | Call `extractCookies` | Temp file deleted even on failure |
| U-DL-CKI-22 | `cookie_helper.dart` | `extractCookies` | **[EDGE]** Temp file doesn't exist on cleanup path | Mock exception before temp file created | Call `extractCookies` | No crash on cleanup, returns `null` |
