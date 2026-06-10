# CookieHelper Unit Test Plan

**File Under Test:** `lib/features/downloader/services/cookie_helper.dart`
**Target Layer:** Services
**Coverage Target:** >90%

## 1. Cookie Extraction Logic

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DL-CKI-01 | `cookie_helper.dart` | `extractCookies` | Reject Chromium-based browsers instantly | `browser = 'Google Chrome'` | Call `extractCookies` | Returns `null` immediately |
| U-DL-CKI-02 | `cookie_helper.dart` | `extractCookies` | Parse SQLite DB for Firefox | Mock Firefox profile dir containing `cookies.sqlite` with 1 Instagram row | Call `extractCookies(browser: 'Firefox')` | Returns string `'cookieName=cookieValue'` |
| U-DL-CKI-03 | `cookie_helper.dart` | `extractCookies` | Return cached cookies if within TTL | Mock previous extraction | Call `extractCookies(browser: 'Firefox')` | Returns cached string without accessing disk |
| U-DL-CKI-04 | `cookie_helper.dart` | `extractCookies` | Gracefully handle locked or missing databases | Mock locked `cookies.sqlite` | Call `extractCookies` | Returns `null`, cleans up temp files |
