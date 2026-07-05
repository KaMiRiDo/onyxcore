# OnyxCore — Consolidated Test Guide

> Single reference for all test design, structure, and implementation decisions across the project.

---

## 1. Directory & File Structure

### Folder Layout

```
test/
├── core/                          ← Core-level shared logic tests
│   ├── playlist/
│   └── window_management/
├── features/                      ← Feature-first, mirroring lib/features/
│   └── <module>/
│       ├── domain/                ← Entity & utils unit tests
│       │   ├── entities/
│       │   └── utils/
│       ├── data/                  ← Datasource & repository tests
│       │   ├── datasources/
│       │   └── repositories/
│       ├── presentation/          ← Widget tests for pages & widgets
│       │   ├── pages/
│       │   └── widgets/
│       └── unit/                  ← Isolate / compute function tests
├── services/                      ← Top-level shared service tests
│   └── unit/
├── helpers/                       ← Shared test utilities & factories
│   └── file_system_helper.dart
└── mocks/                         ← Central mock registry (mocktail)
    └── mocks.dart
```

**Rule:** `test/` must mirror `lib/` exactly. A file at `lib/features/audio_player/domain/entities/audio_track.dart` → test at `test/features/audio_player/domain/entities/audio_track_test.dart`.

### File Naming

| Artifact | Pattern |
|---|---|
| Test code | `<original_filename>_test.dart` |
| Test documentation | `<original_filename>_test_doc.md` |

Test docs live at `_artifacts/test_docs/` mirroring the same tree.

---

## 2. Test File Anatomy

Every test file follows this exact order:

```dart
// 1. Imports (dart → flutter → package → relative)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/...';

// 2. Test infrastructure (factories, helpers)
Map<String, dynamic> makeItem({required String name}) { ... }
Future<void> pumpDialog(WidgetTester tester, ...) async { ... }

// 3. main()
void main() {
  GoogleFonts.config.allowRuntimeFetching = false; // always first if fonts used

  setUpAll(() { ... });
  tearDownAll(() { ... });
  setUp(() { ... });
  tearDown(() { ... });

  group('ClassName / functionName', () {
    // ── U-MOD-01 ──
    test('U-MOD-01: scenario description', () { ... });
  });
}

// 4. Mock Notifiers (for widget tests — defined after main)
class MockTaskNotifier extends TaskNotifier { ... }
```

---

## 3. Naming & Traceability

### Test Case Names

Every test name **must include its Test ID** from the test doc:

```dart
// ✅ Correct
test('U-AUD-TRACK-01: creates an AudioTrack with all required fields', ...);
testWidgets('W-AUD-PROP-05: closes dialog on Escape key', ...);

// ❌ Wrong
test('should create audio track', ...);
```

### Visual Separators

```dart
// Unit tests
// ── U-AUD-TRACK-01 ──
test(...);

// Widget tests
// ═══════════════════════════════════════════════════════════════
// W-AUD-PROP-01: Loading Spinner
// ═══════════════════════════════════════════════════════════════
testWidgets(...);
```

### Test ID Format

| Test Type | Format | Example |
|---|---|---|
| Unit | `U-[MOD]-[NN]` | `U-AUD-TRACK-01` |
| Widget | `W-[MOD]-[NN]` | `W-AUD-PROP-05` |

---

## 4. Core Testing Principles

| Principle | Rule |
|---|---|
| **Host isolation** | Never touch the real filesystem. Use `MemoryFileSystem` for datasource/repo tests |
| **Real filesystem for isolates** | Isolate/compute functions call `dart:io` directly → use `Directory.systemTemp` |
| **Dependency injection** | All services and providers must accept DI so mocks can be injected |
| **Targeted mocking** | Mock heavy dependencies (repos, APIs, native controllers). Never mock plain data models or pure utility functions |
| **No network** | `GoogleFonts.config.allowRuntimeFetching = false` in every `main()` that uses fonts |
| **No hardcoded paths** | Use `Directory.systemTemp`, relative paths, or injected paths |

---

## 5. Unit Test Patterns

### 5.1 Entities (Equatable)

Cover these for every Equatable entity:

| Test | What to verify |
|---|---|
| Required fields constructor | No null/type errors |
| Optional fields constructor | Default values correct |
| Null optional fields | Nullable handling |
| Equality (same fields) | `Equatable.props` works |
| Inequality (each field) | Each prop participates |
| `hashCode` consistency | Equal objects = equal hashes |
| `props` list length | Guards against missing fields |

```dart
test('U-AUD-TRACK-09: includes all 5 fields in props list', () {
  const track = AudioTrack(title: 'Song', artist: 'Artist', path: '/path',
      albumArtPath: '/art', duration: Duration(seconds: 120));
  expect(track.props, hasLength(5));
});
```

### 5.2 Pure Utility Functions

- No mocking — test inputs/outputs directly.
- Cover: empty lists, zero, max int, null inputs, boundary values.

### 5.3 Isolate / Compute Functions

Always use `Directory.systemTemp`:

```dart
late Directory tempDir;

setUp(() {
  tempDir = Directory.systemTemp.createTempSync('onyx_test_');
});

tearDown(() {
  if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
});
```

Permission-denied test pattern (must restore for tearDown):

```dart
Process.runSync('chmod', ['000', dir.path]);
// ... run function ...
Process.runSync('chmod', ['755', dir.path]); // MUST restore
```

### 5.4 JSON / Serialization

```dart
test('correctly deserializes from JSON', () {
  final json = {'path': '/music/file.mp3', 'name': 'file.mp3', ...};
  final result = MyEntity.fromJson(json);
  expect(result.path, '/music/file.mp3');
});
```

### 5.5 Optional System Tools (e.g., ffprobe)

```dart
late bool hasFfprobe;

setUpAll(() {
  hasFfprobe = Process.runSync('which', ['ffprobe']).exitCode == 0;
});

test('U-AUD-01: parses bitrate from WAV file', () {
  if (!hasFfprobe) { markTestSkipped('ffprobe not available'); return; }
  // ... test ...
});
```

### 5.6 Provider / Notifier Tests (Riverpod)

Use an in-memory database and `ProviderContainer` with overrides:

```dart
late ProviderContainer container;
late AppDatabase db;

setUp(() async {
  db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
});

tearDown(() async {
  container.dispose();
  await db.close();
});
```

---

## 6. Widget Test Patterns

### 6.1 Pump Helpers

Define a reusable `pumpDialog` / `pumpWidget` helper per test file:

```dart
Future<void> pumpDialog(WidgetTester tester, {required String path}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(body: MyDialog(path: path)),
    ),
  );
  await tester.pumpAndSettle();
}
```

### 6.2 Dependency Injection for Widgets

When a widget makes FFI/native/heavy I/O calls in `initState`, add optional test overrides:

```dart
class MyDialog extends StatefulWidget {
  final String path;
  final Tag? testTag;           // optional DI — null in production
  final FileStat? testStat;     // optional DI — null in production

  const MyDialog({super.key, required this.path, this.testTag, this.testStat});
}
```

**Rules:**
- All override fields are optional with `null` defaults.
- `_loadData()` checks: if override is non-null, use it; otherwise use the real path.
- Production `show()` call sites never pass these parameters.

### 6.3 Riverpod Widget Tests

Use `ProviderScope` with `overrideWith`:

```dart
Widget createWidget(List<String> paths) {
  return ProviderScope(
    overrides: [taskProvider.overrideWith(() => mockTaskNotifier)],
    child: MaterialApp(home: Scaffold(body: MyWidget(paths: paths))),
  );
}
```

### 6.4 Testing `showDialog` Route Behavior

```dart
await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Builder(builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog<void>(context: context, builder: (_) => MyDialog(...));
        });
        return const SizedBox.expand();
      }),
    ),
  ),
);
await tester.pump();           // trigger post-frame callback
await tester.pumpAndSettle();
```

### 6.5 Widget Assertion Patterns

| Scenario | Pattern |
|---|---|
| Widget exists | `expect(find.byType(MyWidget), findsOneWidget)` |
| Text content | `expect(find.text('Expected'), findsOneWidget)` |
| Widget with text | `expect(find.widgetWithText(ElevatedButton, 'Close'), findsOneWidget)` |
| Icon exists | `expect(find.byIcon(Icons.close), findsOneWidget)` |
| Widget property | `tester.widget<Text>(find.text('X')).style?.color` |
| Ancestor check | `find.ancestor(of: childFinder, matching: parentFinder)` |
| Predicate | `find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 500)` |
| At least N | `expect(find.text('X'), findsAtLeast(4))` |
| Duplicate values | `expect(find.text(value), findsNWidgets(2))` when two fields show same text |

### 6.6 Keyboard Shortcuts

```dart
// Single key
await tester.sendKeyEvent(LogicalKeyboardKey.escape);
await tester.pumpAndSettle();

// Modifier + key
await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
await tester.pumpAndSettle();
```

### 6.7 Dialog Dismissal — Test All Three Vectors

```dart
// 1. Escape key
await tester.sendKeyEvent(LogicalKeyboardKey.escape);

// 2. Close icon button
await tester.tap(find.byIcon(Icons.close));

// 3. Footer action button
await tester.tap(find.widgetWithText(ElevatedButton, 'Close'));

// After each:
await tester.pumpAndSettle();
expect(find.byType(MyDialog), findsNothing);
```

---

## 7. Coverage Requirements (>90% Target)

| Category | Must Cover |
|---|---|
| Happy paths | Standard data flow and behavior |
| Edge cases | Empty lists, null inputs, boundary values, zero-state renders |
| Error handling | `try-catch`, `FileSystemException`, permission denial, malformed data |
| UI state transitions | Loading → loaded, enabled → disabled, visible → hidden |
| Keyboard shortcuts | Every registered shortcut + guards |
| Styling / theming | Colors, font sizes, border radius, opacity |
| Layout | Flex ratios, fixed widths, padding values |
| Dismissal | All close/pop paths |

### When to Skip

```dart
testWidgets(
  'W-AUD-PROP-11: formats bytes for gigabytes',
  (tester) async { },
  skip: true, // Skip: Creating 1 GB temp file is impractical for CI
);
```

Valid reasons: impractical fixture size, FFI plugins unavailable in test harness, platform-specific behavior.

---

## 8. Shared Helpers

### `test/helpers/file_system_helper.dart`

Returns a pre-populated `MemoryFileSystem` with a realistic Linux home tree. Import in setUp for datasource/repo tests:

```dart
import '../../helpers/file_system_helper.dart';

late MemoryFileSystem fs;
setUp(() { fs = setupMockFileSystem(); });
```

### `test/mocks/mocks.dart`

Central `mocktail` mock registry. All `Mock` class definitions go here:

```dart
class MockSettingsRepository extends Mock implements SettingsRepository {}
class MockDirectoryRepository extends Mock implements DirectoryRepository {}
```

---

## 9. Common Pitfalls & Fixes

| Pitfall | Fix |
|---|---|
| `pumpAndSettle` timeout | Widget has unresolvable async (FFI, infinite animation). Use DI to bypass or use `pump(Duration)` |
| `MemoryFileSystem` breaks isolate tests | Isolate functions call `dart:io` directly → use `Directory.systemTemp` |
| `FileStat` / `ProcessResult` can't be mocked | They're `final`. Use real temp files to obtain real instances |
| `Process.run` not overridable | Synthesize real files + call actual process. Use `markTestSkipped` as fallback |
| State leaks between tests | Use `setUp`/`tearDown` for per-test resources. `setUpAll`/`tearDownAll` only for expensive shared fixtures |
| Private methods untestable | Test via public API. Add `@visibleForTesting` only when critical |
| GoogleFonts network calls | `GoogleFonts.config.allowRuntimeFetching = false` in `main()` |

---

## 10. Test Document Template

Every `<filename>_test_doc.md` must use these tables. Mark inapplicable sections as `N/A - Pure [Layer] Logic`.

### Unit Test Plan

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-[MOD]-01 | | | | | | |

### Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-[MOD]-01 | | | | | | |

---

## 11. Running Tests

```bash
# All tests
flutter test --reporter expanded

# Specific file
flutter test test/features/audio_player/domain/entities/audio_track_test.dart --reporter expanded

# Specific directory
flutter test test/features/audio_player/ --reporter expanded

# Filter by name
flutter test --name "U-AUD" --reporter expanded
```

---

## 12. Pre-Submission Checklist

- [ ] `dart analyze <test_file>` → **0 errors, 0 warnings**
- [ ] `flutter test <test_file> --reporter expanded` → all green
- [ ] Every Test ID in the test doc has a matching `test()` / `testWidgets()` call
- [ ] Production code changes (DI parameters) verified not to break existing call sites
- [ ] All `setUp` resources cleaned up in `tearDown` (temp dirs, permissions restored)
- [ ] No hardcoded absolute paths
- [ ] No network calls (GoogleFonts disabled)
- [ ] Any `skip: true` has an explanatory comment
