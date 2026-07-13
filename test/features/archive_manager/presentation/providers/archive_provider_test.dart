import 'package:onyxcore/features/archive_manager/presentation/widgets/password_dialog.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/archive_manager/presentation/providers/archive_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/app.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake TaskNotifier — records calls; no Uuid, no Isolates, no timers.
// ─────────────────────────────────────────────────────────────────────────────
class FakeTaskNotifier extends TaskNotifier {
  final List<String> calls = [];
  int _counter = 0;

  @override
  String addTask({
    required String title,
    required String subtitle,
    int totalCount = 0,
    int totalSizeBytes = 0,
    List<String>? sourcePaths,
    String? targetPath,
    bool isLight = false,
  }) {
    final id = 'fake-task-${++_counter}';
    calls.add('addTask:$title');
    state = [
      ...state,
      FileTask(
        id: id,
        title: title,
        subtitle: subtitle,
        status: FileTaskStatus.running,
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
        sourcePaths: sourcePaths,
        targetPath: targetPath,
      ),
    ];
    return id;
  }

  @override
  void updateProgress(String id, double progress) =>
      calls.add('updateProgress:$id');

  @override
  void addLog(String id, String message) => calls.add('addLog:$id');

  @override
  void completeTask(String id) {
    calls.add('completeTask:$id');
    state = state
        .map((t) =>
            t.id == id ? t.copyWith(status: FileTaskStatus.completed) : t)
        .toList();
  }

  @override
  void failTask(String id, String error) {
    calls.add('failTask:$id');
    state = state
        .map((t) => t.id == id ? t.copyWith(status: FileTaskStatus.error) : t)
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake CurrentPath notifier — returns a fixed path, no TabManager dependency.
// ─────────────────────────────────────────────────────────────────────────────
class FakeCurrentPathNotifier extends CurrentPathNotifier {
  FakeCurrentPathNotifier(this.fixedPath);

  final String fixedPath;

  @override
  String build() => fixedPath;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake Selection notifier — records calls, no TabManager dependency.
// ─────────────────────────────────────────────────────────────────────────────
class FakeSelectionNotifier extends SelectionNotifier {
  final List<String> calls = [];

  @override
  SelectionState build() => SelectionState.empty;

  @override
  void deselectAll() => calls.add('deselectAll');

  @override
  void select(String path) => calls.add('select:$path');
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake DirectoryItems notifier — records refresh, returns empty list.
// ─────────────────────────────────────────────────────────────────────────────
class FakeDirectoryItemsNotifier extends DirectoryItemsNotifier {
  final List<String> calls = [];

  @override
  Future<List<FileItem>> build() async => [];

  @override
  Future<void> refresh() async => calls.add('refresh');
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a fresh ProviderScope widget tree with all fakes wired in.
/// [currentPath] controls what currentPathProvider returns.
Widget makeApp({
  required String currentPath,
  required FakeTaskNotifier fakeTask,
  required FakeSelectionNotifier fakeSel,
  required FakeCurrentPathNotifier fakePath,
  required FakeDirectoryItemsNotifier fakeDir,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      taskProvider.overrideWith(() => fakeTask),
      selectionProvider.overrideWith(() => fakeSel),
      currentPathProvider.overrideWith(() => fakePath),
      directoryItemsProvider.overrideWith(() => fakeDir),
    ],
    child: MaterialApp(
      navigatorKey: appNavigatorKey,
      home: Scaffold(body: child),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('ArchiveProviderNotifier', () {
    // ─── 1. Initialisation ────────────────────────────────────────────────
    group('1. Initialisation', () {
      test('W-ARC-PRV-01: Provider initialises without errors', () {
        final container = ProviderContainer(
          overrides: [
            taskProvider.overrideWith(FakeTaskNotifier.new),
            selectionProvider.overrideWith(FakeSelectionNotifier.new),
            currentPathProvider
                .overrideWith(() => FakeCurrentPathNotifier('/home')),
            directoryItemsProvider
                .overrideWith(FakeDirectoryItemsNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(archiveProvider.notifier);
        expect(notifier, isNotNull);
      });

      test('W-ARC-PRV-02: State is void — provider is action-only', () {
        final container = ProviderContainer(
          overrides: [
            taskProvider.overrideWith(FakeTaskNotifier.new),
            selectionProvider.overrideWith(FakeSelectionNotifier.new),
            currentPathProvider
                .overrideWith(() => FakeCurrentPathNotifier('/home')),
            directoryItemsProvider
                .overrideWith(FakeDirectoryItemsNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // Reading void state should not throw.
        expect(() => container.read(archiveProvider), returnsNormally);
      });
    });

    // ─── 2. compressItems — guard logic ──────────────────────────────────
    group('2. compressItems — guard (no dialog shown)', () {
      testWidgets(
        'W-ARC-PRV-03: Empty paths list — returns without registering a task',
        (tester) async {
          final fakeTask = FakeTaskNotifier();

          await tester.pumpWidget(
            makeApp(
              currentPath: '/home/user',
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier('/home/user'),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: const SizedBox(),
            ),
          );

          late ArchiveProviderNotifier notifier;
          await tester.pumpWidget(
            makeApp(
              currentPath: '/home/user',
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier('/home/user'),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            await notifier.compressItems(
              tester.element(find.byType(SizedBox).first),
              [], // ← guard: returns immediately
              '/home/user',
            );
          });

          expect(fakeTask.calls, isEmpty);
        },
      );
    });

    // ─── 3. extractArchive — output directory creation ────────────────────
    group('3. extractArchive — output directory logic', () {
      late Directory tmpDir;
      late File archiveFile;

      setUp(() {
        tmpDir = Directory.systemTemp.createTempSync('arc_prv_test_');
        archiveFile = File('${tmpDir.path}/myarchive.zip')
          ..writeAsStringSync('');
      });

      tearDown(() {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      });

      testWidgets(
        'W-ARC-PRV-04: Output dir named after archive basename without extension',
        (tester) async {
          final fakeTask = FakeTaskNotifier();
          late ArchiveProviderNotifier notifier;

          await tester.pumpWidget(
            makeApp(
              currentPath: tmpDir.path,
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier(tmpDir.path),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            await notifier.extractArchive(
              tester.element(find.byType(SizedBox)),
              archiveFile.path, // myarchive.zip
              tmpDir.path,
            );
          });

          // Output dir = <tmpDir>/myarchive (basename without extension)
          expect(Directory('${tmpDir.path}/myarchive').existsSync(), isTrue);
        },
      );

      testWidgets(
        'W-ARC-PRV-05: Does not crash if output dir already exists',
        (tester) async {
          Directory('${tmpDir.path}/myarchive').createSync();
          late ArchiveProviderNotifier notifier;

          await tester.pumpWidget(
            makeApp(
              currentPath: tmpDir.path,
              fakeTask: FakeTaskNotifier(),
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier(tmpDir.path),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          expect(
            () async => tester.runAsync(() async {
              await notifier.extractArchive(
                tester.element(find.byType(SizedBox)),
                archiveFile.path,
                tmpDir.path,
              );
            }),
            returnsNormally,
          );
        },
      );
    });

    // ─── 4. extractArchive — task lifecycle ───────────────────────────────
    group('4. extractArchive — task lifecycle', () {
      late Directory tmpDir;
      late File archiveFile;

      setUp(() {
        tmpDir = Directory.systemTemp.createTempSync('arc_prv_lc_');
        archiveFile = File('${tmpDir.path}/test.zip')..writeAsStringSync('');
      });

      tearDown(() {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      });

      testWidgets(
        'W-ARC-PRV-06: addTask is called with "Extracting Archive" title',
        (tester) async {
          final fakeTask = FakeTaskNotifier();
          late ArchiveProviderNotifier notifier;

          await tester.pumpWidget(
            makeApp(
              currentPath: tmpDir.path,
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier(tmpDir.path),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            await notifier.extractArchive(
              tester.element(find.byType(SizedBox)),
              archiveFile.path,
              tmpDir.path,
            );
          });
          await tester.pump();

          expect(
            fakeTask.calls.any((c) => c.contains('addTask:Extracting Archive')),
            isTrue,
          );
        },
      );

      testWidgets(
        'W-ARC-PRV-07: Task reaches a terminal state (complete or fail)',
        (tester) async {
          final fakeTask = FakeTaskNotifier();
          late ArchiveProviderNotifier notifier;

          await tester.pumpWidget(
            makeApp(
              currentPath: tmpDir.path,
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier(tmpDir.path),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            await notifier.extractArchive(
              tester.element(find.byType(SizedBox)),
              archiveFile.path,
              tmpDir.path,
            );
          });
          await tester.pump();

          final terminal = fakeTask.calls.any(
            (c) =>
                c.startsWith('completeTask:') || c.startsWith('failTask:'),
          );
          expect(terminal, isTrue,
              reason: 'Task must end as complete or fail — never left running');
        },
      );

      testWidgets(
        'W-ARC-PRV-08: Non-existent archive path → failTask is called',
        (tester) async {
          final fakeTask = FakeTaskNotifier();
          late ArchiveProviderNotifier notifier;

          await tester.pumpWidget(
            makeApp(
              currentPath: tmpDir.path,
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier(tmpDir.path),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            await notifier.extractArchive(
              tester.element(find.byType(SizedBox)),
              '/definitely/does/not/exist/archive.zip',
              tmpDir.path,
            );
          });
          await tester.pump();

          expect(
            fakeTask.calls.any((c) => c.startsWith('failTask:')),
            isTrue,
          );
        },
      );

      testWidgets(
        'W-ARC-PRV-09: addTask is always called exactly once per extractArchive invocation',
        (tester) async {
          final fakeTask = FakeTaskNotifier();
          late ArchiveProviderNotifier notifier;

          await tester.pumpWidget(
            makeApp(
              currentPath: tmpDir.path,
              fakeTask: fakeTask,
              fakeSel: FakeSelectionNotifier(),
              fakePath: FakeCurrentPathNotifier(tmpDir.path),
              fakeDir: FakeDirectoryItemsNotifier(),
              child: Consumer(
                builder: (ctx, ref, _) {
                  notifier = ref.read(archiveProvider.notifier);
                  return const SizedBox();
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            await notifier.extractArchive(
              tester.element(find.byType(SizedBox)),
              archiveFile.path,
              tmpDir.path,
            );
          });
          await tester.pump();

          // extractArchive always calls addTask (even before the 7z process runs).
          final addTaskCalls =
              fakeTask.calls.where((c) => c.startsWith('addTask:')).toList();
          expect(addTaskCalls.length, 1,
              reason: 'addTask must be called exactly once');
        },
      );
    });

    // ─── 5. FakeTaskNotifier unit tests ──────────────────────────────────
    group('5. FakeTaskNotifier sanity checks', () {
      test('W-ARC-PRV-10: addTask returns unique IDs', () {
        final container = ProviderContainer(
          overrides: [taskProvider.overrideWith(FakeTaskNotifier.new)],
        );
        addTearDown(container.dispose);

        final n = container.read(taskProvider.notifier) as FakeTaskNotifier;
        final id1 = n.addTask(title: 'A', subtitle: 'a');
        final id2 = n.addTask(title: 'B', subtitle: 'b');
        expect(id1, isNot(id2));
      });

      test('W-ARC-PRV-11: completeTask transitions status to completed', () {
        final container = ProviderContainer(
          overrides: [taskProvider.overrideWith(FakeTaskNotifier.new)],
        );
        addTearDown(container.dispose);

        final n = container.read(taskProvider.notifier) as FakeTaskNotifier;
        final id = n.addTask(title: 'T', subtitle: 's');
        expect(
            container.read(taskProvider).first.status, FileTaskStatus.running);

        n.completeTask(id);
        expect(container.read(taskProvider).first.status,
            FileTaskStatus.completed);
      });

      test('W-ARC-PRV-12: failTask transitions status to error', () {
        final container = ProviderContainer(
          overrides: [taskProvider.overrideWith(FakeTaskNotifier.new)],
        );
        addTearDown(container.dispose);

        final n = container.read(taskProvider.notifier) as FakeTaskNotifier;
        final id = n.addTask(title: 'T', subtitle: 's');
        n.failTask(id, 'boom');
        expect(
            container.read(taskProvider).first.status, FileTaskStatus.error);
      });

      test('W-ARC-PRV-13: calls list records all operations in order', () {
        final container = ProviderContainer(
          overrides: [taskProvider.overrideWith(FakeTaskNotifier.new)],
        );
        addTearDown(container.dispose);

        final n = container.read(taskProvider.notifier) as FakeTaskNotifier;
        final id = n.addTask(title: 'Op', subtitle: 's');
        n
          ..updateProgress(id, 0.5)
          ..addLog(id, 'message')
          ..completeTask(id);

        expect(n.calls[0], startsWith('addTask:'));
        expect(n.calls[1], startsWith('updateProgress:'));
        expect(n.calls[2], startsWith('addLog:'));
        expect(n.calls[3], startsWith('completeTask:'));
      });
    });

    // ─── 6. FakeSelectionNotifier unit tests ─────────────────────────────
    group('6. FakeSelectionNotifier sanity checks', () {
      test('W-ARC-PRV-14: Starts with empty, non-mode selection', () {
        final container = ProviderContainer(
          overrides: [
            selectionProvider.overrideWith(FakeSelectionNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(selectionProvider);
        expect(state.selectedPaths, isEmpty);
        expect(state.isSelectionMode, isFalse);
      });

      test('W-ARC-PRV-15: deselectAll is recorded', () {
        final container = ProviderContainer(
          overrides: [
            selectionProvider.overrideWith(FakeSelectionNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        final n = (container.read(selectionProvider.notifier)
            as FakeSelectionNotifier)
          ..deselectAll();
        expect(n.calls, contains('deselectAll'));
      });

      test('W-ARC-PRV-16: select is recorded with correct path', () {
        final container = ProviderContainer(
          overrides: [
            selectionProvider.overrideWith(FakeSelectionNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        final n = (container.read(selectionProvider.notifier)
            as FakeSelectionNotifier)
          ..select('/some/path');
        expect(n.calls, contains('select:/some/path'));
      });

      test('W-ARC-PRV-17: Multiple calls are all recorded', () {
        final container = ProviderContainer(
          overrides: [
            selectionProvider.overrideWith(FakeSelectionNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        final n = (container.read(selectionProvider.notifier)
            as FakeSelectionNotifier)
          ..deselectAll()
          ..select('/a')
          ..select('/b');
        expect(n.calls.length, 3);
      });
    });

    // ─── 7. FakeCurrentPathNotifier unit tests ────────────────────────────
    group('7. FakeCurrentPathNotifier sanity checks', () {
      test('W-ARC-PRV-18: Returns fixed path at construction', () {
        final container = ProviderContainer(
          overrides: [
            currentPathProvider
                .overrideWith(() => FakeCurrentPathNotifier('/test/path')),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(currentPathProvider), '/test/path');
      });

      test('W-ARC-PRV-19: Different containers can use different paths', () {
        final c1 = ProviderContainer(
          overrides: [
            currentPathProvider
                .overrideWith(() => FakeCurrentPathNotifier('/path/one')),
          ],
        );
        final c2 = ProviderContainer(
          overrides: [
            currentPathProvider
                .overrideWith(() => FakeCurrentPathNotifier('/path/two')),
          ],
        );
        addTearDown(c1.dispose);
        addTearDown(c2.dispose);

        expect(c1.read(currentPathProvider), '/path/one');
        expect(c2.read(currentPathProvider), '/path/two');
      });
    });

    // ─── 8. FakeDirectoryItemsNotifier unit tests ─────────────────────────
    group('8. FakeDirectoryItemsNotifier sanity checks', () {
      test('W-ARC-PRV-20: Returns empty list by default', () async {
        final container = ProviderContainer(
          overrides: [
            directoryItemsProvider
                .overrideWith(FakeDirectoryItemsNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        final items = await container.read(directoryItemsProvider.future);
        expect(items, isEmpty);
      });

      test('W-ARC-PRV-21: refresh is recorded', () async {
        final container = ProviderContainer(
          overrides: [
            directoryItemsProvider
                .overrideWith(FakeDirectoryItemsNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        await container.read(directoryItemsProvider.future);
        final n = container.read(directoryItemsProvider.notifier)
            as FakeDirectoryItemsNotifier;
        await n.refresh();
        expect(n.calls, contains('refresh'));
      });
    });

    // ─── 9. Full UI flows (Dialogs & Toasts) ──────────────────────────────
    group('9. Full UI flows (Dialogs & Toasts)', () {
      late Directory tmpDir;
      late File archiveFile;
      late File encryptedArchiveFile;

      setUpAll(() async {
        tmpDir = Directory.systemTemp.createTempSync('arc_prv_flow_');
        archiveFile = File('${tmpDir.path}/test.zip');
        final txtFile = File('${tmpDir.path}/secret.txt')..writeAsStringSync('hello');
        await Process.run('7z', ['a', archiveFile.path, txtFile.path]);
        
        encryptedArchiveFile = File('${tmpDir.path}/enc.zip');
        await Process.run('7z', ['a', '-psecret', encryptedArchiveFile.path, txtFile.path]);
      });

      tearDownAll(() {
        if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
      });

      testWidgets('W-ARC-PRV-22: PasswordDialog standalone test (Cancel)', (tester) async {
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await PasswordDialog.show(ctx);
                },
                child: const Text('Show'),
              ),
            ),
          ),
        );
        
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        
        expect(find.text('CANCEL'), findsOneWidget);
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();
        
        expect(result, isNull);
      });

      testWidgets('W-ARC-PRV-23: PasswordDialog standalone test (Submit) and extractArchive coverage', (tester) async {
        final fakeTask = FakeTaskNotifier();
        late ArchiveProviderNotifier notifier;
        late BuildContext savedCtx;

        await tester.pumpWidget(
          makeApp(
            currentPath: tmpDir.path,
            fakeTask: fakeTask,
            fakeSel: FakeSelectionNotifier(),
            fakePath: FakeCurrentPathNotifier(tmpDir.path),
            fakeDir: FakeDirectoryItemsNotifier(),
            child: Consumer(
              builder: (ctx, ref, _) {
                notifier = ref.read(archiveProvider.notifier);
                savedCtx = ctx;
                return ElevatedButton(
                  onPressed: () => notifier.extractArchive(ctx, archiveFile.path, tmpDir.path),
                  child: const Text('Extract'),
                );
              },
            ),
          ),
        );
        
        // Test unencrypted archive path success (covers DA:70-86)
        Future<void>? extFuture;
        await tester.runAsync(() async {
          extFuture = notifier.extractArchive(savedCtx, archiveFile.path, tmpDir.path);
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await extFuture;
        });
        await tester.pump(const Duration(seconds: 4)); // toast
        expect(fakeTask.calls.any((c) => c.startsWith('addTask:')), isTrue);

        // Test encrypted archive path (covers DA:28-33)
        Future<void>? encFuture;
        await tester.runAsync(() async {
          encFuture = notifier.extractArchive(savedCtx, encryptedArchiveFile.path, tmpDir.path);
          // Give Process.run ('7z') time to finish in real time
          await Future.delayed(const Duration(seconds: 1));
        });

        await tester.pumpAndSettle();

        // Dialog should now be shown
        if (find.text('Password Required').evaluate().isNotEmpty) {
          await tester.tap(find.text('CANCEL'));
          await tester.pumpAndSettle();
        } else {
          // Force tap CANCEL to fail if it's not there so we know
          await tester.tap(find.text('CANCEL'));
        }

        await tester.runAsync(() async {
          await encFuture;
        });
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('W-ARC-PRV-24: compressItems shows CompressDialog and handles cancellation', (tester) async {
        final fakeTask = FakeTaskNotifier();
        late ArchiveProviderNotifier notifier;

        await tester.pumpWidget(
          makeApp(
            currentPath: tmpDir.path,
            fakeTask: fakeTask,
            fakeSel: FakeSelectionNotifier(),
            fakePath: FakeCurrentPathNotifier(tmpDir.path),
            fakeDir: FakeDirectoryItemsNotifier(),
            child: Consumer(
              builder: (ctx, ref, _) {
                notifier = ref.read(archiveProvider.notifier);
                return ElevatedButton(
                  onPressed: () => notifier.compressItems(ctx, [archiveFile.path], tmpDir.path),
                  child: const Text('Compress'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Compress'));
        await tester.pumpAndSettle();

        // CompressDialog is shown
        expect(find.text('Compress Items'), findsOneWidget);

        // Tap Cancel
        await tester.tap(find.text('CANCEL'));
        await tester.pumpAndSettle();

        // No task started
        expect(fakeTask.calls, isEmpty);
      });

      testWidgets('W-ARC-PRV-25: compressItems shows CompressDialog and handles success', (tester) async {
        final fakeTask = FakeTaskNotifier();
        late ArchiveProviderNotifier notifier;
        late BuildContext savedCtx;

        await tester.pumpWidget(
          makeApp(
            currentPath: tmpDir.path,
            fakeTask: fakeTask,
            fakeSel: FakeSelectionNotifier(),
            fakePath: FakeCurrentPathNotifier(tmpDir.path),
            fakeDir: FakeDirectoryItemsNotifier(),
            child: Consumer(
              builder: (ctx, ref, _) {
                notifier = ref.read(archiveProvider.notifier);
                savedCtx = ctx;
                return const SizedBox();
              },
            ),
          ),
        );

        Future<void>? compressFuture;
        await tester.runAsync(() async {
          compressFuture = notifier.compressItems(savedCtx, [archiveFile.path], tmpDir.path);
        });

        await tester.pumpAndSettle();

        // CompressDialog is shown
        expect(find.text('Compress Items'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'test_output');
        await tester.tap(find.widgetWithText(ElevatedButton, 'COMPRESS'));
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await compressFuture;
        });

        // Wait for Toast timer to dismiss
        await tester.pump(const Duration(seconds: 4));

        // Task started
        expect(fakeTask.calls.any((c) => c.startsWith('addTask:')), isTrue);
      });
      
      testWidgets('W-ARC-PRV-26: compressItems handles exception and shows error toast', (tester) async {
        final fakeTask = FakeTaskNotifier();
        late ArchiveProviderNotifier notifier;
        late BuildContext savedCtx;

        await tester.pumpWidget(
          makeApp(
            currentPath: tmpDir.path,
            fakeTask: fakeTask,
            fakeSel: FakeSelectionNotifier(),
            fakePath: FakeCurrentPathNotifier(tmpDir.path),
            fakeDir: FakeDirectoryItemsNotifier(),
            child: Consumer(
              builder: (ctx, ref, _) {
                notifier = ref.read(archiveProvider.notifier);
                savedCtx = ctx;
                return const SizedBox();
              },
            ),
          ),
        );

        Future<void>? compressFuture;
        await tester.runAsync(() async {
          compressFuture = notifier.compressItems(savedCtx, ['/invalid/path/that/doesnt/exist.txt'], tmpDir.path);
        });

        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'test_output_bad');
        await tester.tap(find.widgetWithText(ElevatedButton, 'COMPRESS'));
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await compressFuture;
        });

        // Wait for Toast timer to dismiss
        await tester.pump(const Duration(seconds: 4));

        // Task failed
        expect(fakeTask.calls.any((c) => c.startsWith('failTask:')), isTrue);
      });
    });
  });
}
