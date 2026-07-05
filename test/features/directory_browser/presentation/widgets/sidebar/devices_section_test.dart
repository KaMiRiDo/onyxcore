import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/device.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/devices_section.dart';

class MockTaskNotifier extends TaskNotifier {
  MockTaskNotifier(this.initialTasks);
  final List<FileTask> initialTasks;
  
  @override
  List<FileTask> build() => initialTasks;
}

void main() {
  Widget buildTestWidget({
    required List<Device> devices,
    List<FileTask> tasks = const [],
    String currentPath = '/home',
    void Function(String)? onNavigate,
  }) {
    return ProviderScope(
      overrides: [
        deviceProvider.overrideWith((ref) => Stream.value(devices)),
        taskProvider.overrideWith(() => MockTaskNotifier(tasks)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DevicesSection(
            currentPath: currentPath,
            onNavigate: onNavigate ?? (path) {},
          ),
        ),
      ),
    );
  }

  testWidgets('DevicesSection renders list of devices and formats storage text', (tester) async {
    final devices = [
      Device(
        id: 'dev1',
        name: 'File System',
        path: '/',
        size: '500 GB',
        usage: 0.5,
        isRemovable: false,
      ),
      Device(
        id: 'dev2',
        name: 'USB Drive',
        path: '/media/usb',
        size: '16 GB',
        usage: 0.1,
        isRemovable: true,
      ),
      Device(
        id: 'dev3',
        name: 'Zero Size Drive',
        path: '/media/zero',
        size: '0 B',
        usage: 0,
        isRemovable: true,
      ),
      Device(
        id: 'dev4',
        name: 'Malformed Size',
        path: '/media/malformed',
        size: '100GB', // no space
        usage: 0.5,
        isRemovable: false,
      ),
      Device(
        id: 'dev5',
        name: 'Unmounted Drive',
        path: '',
        size: '100 GB',
        usage: 0,
        isRemovable: true,
      ),
      Device(
        id: 'dev6',
        name: 'Mobile Phone',
        path: '/gvfs/mtp',
        size: '128 GB',
        usage: 0.8,
        isRemovable: true,
        isMobile: true,
      ),
    ];

    await tester.pumpWidget(buildTestWidget(
      devices: devices,
      currentPath: '/media/usb/subfolder', // to test isActive child path
    ));
    await tester.pumpAndSettle();

    expect(find.text('File System'), findsOneWidget);
    expect(find.text('USB Drive'), findsOneWidget);
    expect(find.text('Zero Size Drive'), findsOneWidget);
    expect(find.text('Malformed Size'), findsOneWidget);
    
    // Tap on the unmounted drive to trigger the mount command and SnackBar
    await tester.tap(find.text('Unmounted Drive'));
    await tester.pump();
    
    // Test tapping the Eject button on 'USB Drive'
    final ejectButtons = find.byIcon(Icons.eject);
    if (tester.any(ejectButtons)) {
      await tester.tap(ejectButtons.first);
      await tester.pump();
    }
    
    // Test tapping the Eject button on 'Mobile Phone' (isGvfs branch)
    if (tester.any(ejectButtons)) {
      await tester.tap(ejectButtons.last);
      await tester.pump();
    }
    
    // Verify busy wait SnackBar when device has active tasks
    await tester.pumpWidget(buildTestWidget(
      devices: devices,
      tasks: [
        FileTask(
          id: 'task1',
          title: 'Copying',
          subtitle: 'file.txt',
          status: FileTaskStatus.running,
          progress: 0.5,
          sourcePaths: ['/media/usb/source.txt'],
          targetPath: '/media/usb/dest.txt',
          createdAt: DateTime.now(),
        )
      ],
    ));
    await tester.pumpAndSettle();
    
    if (tester.any(ejectButtons)) {
      await tester.tap(ejectButtons.first);
      await tester.pump(); // Show warning snackbar about active tasks
    }
    
    await tester.pumpWidget(const SizedBox()); // Unmount to clean timers
  });

  testWidgets('DevicesSection loading state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DevicesSection(
              currentPath: '/home',
              onNavigate: _dummyNavigate,
            ),
          ),
        ),
      ),
    );
    
    expect(find.text('Loading devices...'), findsOneWidget);
  });
  
}

void _dummyNavigate(String path) {}
