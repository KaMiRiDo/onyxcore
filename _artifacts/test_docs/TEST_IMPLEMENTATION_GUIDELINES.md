# OnyxCore Test Implementation Guidelines

This document provides the definitive implementation-level guidelines for writing unit tests and widget tests in the OnyxCore project. It supplements the [REGRESSION_TEST_GUIDELINES.md](./REGRESSION_TEST_GUIDELINES.md) (which covers test *design* and documentation) with concrete patterns, code conventions, and strategies proven in the codebase.

**Target: >90% code coverage across all modules.**

---

## 1. Directory & File Structure

### 1.1 Mirroring Convention

The `test/` directory mirrors `lib/` exactly, split by test type:

```
test/
├── unit/           ← Pure logic: entities, utils, isolates, providers
│   └── features/
│       └── <module>/
│           └── domain/
│               ├── entities/<name>_test.dart
│               └── utils/<name>_test.dart
├── widgets/        ← Widget/UI tests: dialogs, pages, widgets
│   └── features/
│       └── <module>/
│           └── presentation/
│               ├── pages/<name>_test.dart
│               └── widgets/dialogs/<name>_test.dart
├── helpers/        ← Shared test utilities, factories, builders
└── mocks/          ← Shared mock classes (mocktail)
```

### 1.2 File Naming

| Artifact | Naming Pattern |
|---|---|
| Test code | `<original_filename>_test.dart` |
| Test documentation | `<original_filename>_test_doc.md` |

---

## 2. Test Anatomy & Conventions

### 2.1 Standard Test File Structure

Every test file should follow this order:

```dart
// 1. Imports (dart, flutter_test, package, relative)
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/...';

// 2. Test Infrastructure (helpers, factories, shared state)
late Directory _tempDir;

Map<String, dynamic> makeItem({required String name, ...}) { ... }

Future<void> pumpDialog(WidgetTester tester, ...) async { ... }

// 3. main()
void main() {
  // 3a. Global configuration (e.g. GoogleFonts)
  GoogleFonts.config.allowRuntimeFetching = false;

  // 3b. Lifecycle hooks
  setUpAll(() { ... });
  tearDownAll(() { ... });
  setUp(() { ... });
  tearDown(() { ... });

  // 3c. Test groups and cases
  group('ClassName / functionName', () {
    test('scenario description', () { ... });
  });
}
```

### 2.2 Test Case Naming

Test names must include the **Test ID** from the test document for traceability:

```dart
// ✅ Good
test('U-AUD-TRACK-01: creates an AudioTrack with all required fields', ...);
testWidgets('W-AUD-PROP-05: closes dialog on Escape key', ...);

// ❌ Bad
test('should create audio track', ...);
```

### 2.3 Section Separators

Use visual separators between test IDs for readability:

```dart
// ── U-AUD-TRACK-01 ──
test('...', () { ... });

// ── U-AUD-TRACK-02 ──
test('...', () { ... });
```

Or for widget tests, use block separators:

```dart
// ═══════════════════════════════════════════════════════════════
// W-AUD-PROP-01: Loading Spinner
// ═══════════════════════════════════════════════════════════════
testWidgets('W-AUD-PROP-01: shows loading spinner ...', ...);
```

---

## 3. Unit Test Patterns

### 3.1 Entity / Model Testing

For `Equatable` entities, always verify:

| What to test | Why |
|---|---|
| Constructor with all required fields | Ensures no null/type issues |
| Constructor with optional fields | Validates default values |
| Constructor with null optional fields | Tests nullable handling |
| Equality between identical objects | Verifies `Equatable.props` |
| Inequality for each field changed | Proves each prop participates |
| `hashCode` consistency | Equal objects must produce equal hashes |
| `props` list completeness | Guards against missing fields in equality |

```dart
test('considers two AudioTracks with same fields as equal', () {
  final a = AudioTrack(title: 'Song', path: '/a.mp3', ...);
  final b = AudioTrack(title: 'Song', path: '/a.mp3', ...);
  expect(a, equals(b));
});

test('includes all fields in props list', () {
  final track = AudioTrack(...);
  expect(track.props, hasLength(5));
});
```

### 3.2 Pure Utility / Function Testing

For stateless utility functions:

- **No mocking needed** — test inputs and outputs directly.
- Cover **boundary values**: empty lists, zero, max int, null inputs.
- For functions with external dependencies (e.g., `Process.run`, FFI), use **real-file-first** strategy:

```dart
// Synthesize a real file for ffprobe to consume
final wavBytes = _buildMinimalWavFile(sampleRate: 44100);
final tempFile = File('${tempDir.path}/test.wav')
  ..writeAsBytesSync(wavBytes);

final result = await AudioMetadataUtils.getProperties(tempFile.path);
expect(result.sampleRate, contains('44100'));
```

### 3.3 Isolate / Compute Function Testing

For functions passed to `compute()`:

- Use **real `Directory.systemTemp`** temporary directories.
- Create real files on disk (the isolate function accesses the filesystem directly).
- Always clean up in `tearDown`:

```dart
late Directory tempDir;

setUp(() {
  tempDir = Directory.systemTemp.createTempSync('test_prefix_');
});

tearDown(() {
  if (tempDir.existsSync()) {
    tempDir.deleteSync(recursive: true);
  }
});
```

- Test permission-denied scenarios using `chmod`:

```dart
test('handles permission-denied folder gracefully', () {
  final dir = Directory('${tempDir.path}/restricted')..createSync();
  Process.runSync('chmod', ['000', dir.path]);

  // ... run function ...

  // MUST restore permissions so tearDown can delete
  Process.runSync('chmod', ['755', dir.path]);
});
```

### 3.4 Serialization / JSON Testing

When testing `fromJson` / `toJson`:

```dart
test('correctly deserializes FileItem from JSON map', () {
  final json = {
    'path': '/music/file.mp3',
    'name': 'file.mp3',
    'type': FileItemType.audio.index,
    'modified': DateTime(2026).millisecondsSinceEpoch,
    ...
  };
  final result = processFunction({'items': [json], ...});
  expect(result[0].path, '/music/file.mp3');
});
```

### 3.5 Graceful Fallbacks

For tests that depend on optional system tools (e.g., `ffprobe`):

```dart
late bool hasFfprobe;

setUpAll(() {
  final result = Process.runSync('which', ['ffprobe']);
  hasFfprobe = result.exitCode == 0;
});

test('parses bitrate from real WAV file', () {
  if (!hasFfprobe) {
    markTestSkipped('ffprobe not available on this system');
    return;
  }
  // ... actual test ...
});
```

---

## 4. Widget Test Patterns

### 4.1 Pump Helpers

Create reusable pump helpers at the top of the test file to standardize widget mounting:

```dart
/// Pumps the dialog inside a minimal MaterialApp with the app theme.
Future<void> pumpDialog(
  WidgetTester tester, {
  required String path,
  FileStat? stat,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: MyDialog(path: path, testStat: stat),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

### 4.2 Dependency Injection for Widget Tests

When a widget makes **FFI calls, native plugin calls, or heavy I/O** in `initState`, add optional constructor parameters to bypass those calls in tests:

```dart
// Production code
class MyDialog extends StatefulWidget {
  final String path;

  /// Optional overrides for testing — bypasses FFI and filesystem calls.
  final Tag? testTag;
  final AudioProperties? testProperties;
  final FileStat? testStat;

  const MyDialog({
    super.key,
    required this.path,
    this.testTag,
    this.testProperties,
    this.testStat,
  });
}
```

**Rules for test overrides:**
- All override fields must be **optional with `null` defaults**.
- The `_loadData()` method must check: if any override is non-null, use injected data; otherwise, follow the real production path.
- Production call sites (e.g., `show()` method) must never pass these parameters.
- This is a **non-breaking, additive change** — existing callers are unaffected.

### 4.3 Testing `showDialog` Behavior

To test barrier color, route behavior, and dialog dismissal:

```dart
Future<void> pumpDialogViaShow(WidgetTester tester, String path) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black.withAlpha(179),
                builder: (context) => MyDialog(path: path, ...),
              );
            });
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  await tester.pump(); // trigger post-frame callback
  await tester.pumpAndSettle();
}
```

### 4.4 Widget Assertion Patterns

| Scenario | Pattern |
|---|---|
| Widget exists | `expect(find.byType(MyWidget), findsOneWidget)` |
| Text content | `expect(find.text('Expected'), findsOneWidget)` |
| Widget with text | `expect(find.widgetWithText(ElevatedButton, 'Close'), findsOneWidget)` |
| Icon exists | `expect(find.byIcon(Icons.close), findsOneWidget)` |
| Widget property | `final w = tester.widget<Text>(find.text('X')); expect(w.style?.color, ...)` |
| Ancestor check | `find.ancestor(of: childFinder, matching: parentFinder)` |
| Predicate | `find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 500)` |
| At least N | `expect(find.text('Unknown'), findsAtLeast(4))` |
| Duplicate text | Use `findsNWidgets(2)` when identical strings appear (e.g., same timestamp for changed/modified) |

### 4.5 Keyboard Shortcut Testing

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

### 4.6 Dialog Dismissal Testing

Three common dismissal vectors — test all of them:

```dart
// 1. Escape key
await tester.sendKeyEvent(LogicalKeyboardKey.escape);

// 2. Close icon button
await tester.tap(find.byIcon(Icons.close));

// 3. Footer action button
await tester.tap(find.widgetWithText(ElevatedButton, 'Close'));

// After each: verify dialog is gone
await tester.pumpAndSettle();
expect(find.byType(MyDialog), findsNothing);
```

### 4.7 GoogleFonts in Tests

Always disable runtime fetching to prevent network calls:

```dart
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  // ...
}
```

---

## 5. Coverage Strategy

### 5.1 What to Cover (>90% Target)

| Category | Must Cover |
|---|---|
| **Happy paths** | Standard expected behavior and data flow |
| **Edge cases** | Empty lists, null inputs, boundary values, zero-state renders |
| **Error handling** | `try-catch` blocks, `FileSystemException`, permission denials, malformed data |
| **UI state transitions** | Loading → loaded, enabled → disabled, visible → hidden |
| **Keyboard shortcuts** | Every registered shortcut + guards (e.g., ignore when text field focused) |
| **Styling/theming** | Colors, font sizes, border radius, gradients, opacity values |
| **Layout** | Flex ratios, fixed widths (SizedBox), padding values |
| **Dismissal** | All close/pop paths for dialogs and overlays |

### 5.2 When to Skip Tests

Use `skip: true` with a comment explaining the rationale:

```dart
testWidgets(
  'W-AUD-PROP-11: formats bytes correctly for gigabytes',
  (tester) async { },
  // Skip: Creating a 1 GB temp file is impractical for CI.
  skip: true,
);
```

Valid skip reasons:
- Creating impractically large test fixtures (e.g., 1 GB files)
- FFI native plugins unavailable in test harness (e.g., `audiotags`)
- Platform-specific behavior (document which platform is required)

### 5.3 Handling Duplicate Values in Assertions

When two fields may resolve to the same display value:

```dart
if (expectedChanged == expectedModified) {
  expect(find.text(expectedChanged), findsNWidgets(2));
} else {
  expect(find.text(expectedChanged), findsOneWidget);
  expect(find.text(expectedModified), findsOneWidget);
}
```

---

## 6. Common Pitfalls & Solutions

| Pitfall | Solution |
|---|---|
| `pumpAndSettle` times out | The widget has an unresolvable async dependency (FFI, infinite animation). Use dependency injection to bypass, or use `pump(Duration)` instead |
| `MemoryFileSystem` vs real filesystem | Use `MemoryFileSystem` for repository/service tests. Use `Directory.systemTemp` for isolate/compute functions that call `dart:io` directly |
| `FileStat` / `ProcessResult` are `final` | Cannot be mocked or constructed. Use real temp files to obtain real `FileStat` objects |
| `Process.run` not overridable | Cannot use `IOOverrides`. Synthesize real files and call the actual process, with `markTestSkipped` fallback |
| Test leaks state between runs | Use `setUp`/`tearDown` for per-test isolation. Use `setUpAll`/`tearDownAll` only for expensive shared fixtures |
| Private methods untestable directly | Test indirectly via the public API that calls them. If critical, add `@visibleForTesting` |
| GoogleFonts network calls | Set `GoogleFonts.config.allowRuntimeFetching = false` in `main()` |

---

## 7. Running Tests

```bash
# Run all tests
flutter test --reporter expanded

# Run specific test file
flutter test test/unit/features/.../my_test.dart --reporter expanded

# Run specific test directory
flutter test test/unit/features/audio_player/domain/ --reporter expanded

# Run tests matching a keyword
flutter test --name "hidden" --reporter expanded

# Run with coverage
flutter test --coverage

# Generate coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
```

---

## 8. Verification Checklist

Before submitting any test implementation, verify:

- [ ] **Static analysis clean**: `dart analyze <test_file>` reports **0 errors, 0 warnings** (info-level is acceptable)
- [ ] **All tests pass**: `flutter test <test_file> --reporter expanded` shows all green
- [ ] **Test IDs match doc**: Every test case in the test doc has a corresponding `test()` or `testWidgets()` call
- [ ] **No production regressions**: Any production code changes (e.g., DI parameters) are verified to not affect existing call sites
- [ ] **Cleanup guaranteed**: All `setUp` resources are cleaned up in `tearDown` (especially temp directories and permissions)
- [ ] **No hardcoded paths**: Tests use `Directory.systemTemp`, relative paths, or injected paths — never absolute user paths
- [ ] **No network calls**: Tests run fully offline (GoogleFonts disabled, no HTTP fetches)
- [ ] **Skipped tests documented**: Any `skip: true` has a comment explaining why
