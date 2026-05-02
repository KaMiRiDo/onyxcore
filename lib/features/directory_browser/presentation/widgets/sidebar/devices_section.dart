import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar_item.dart';
import 'dart:io';

class DevicesSection extends ConsumerWidget {
  const DevicesSection({
    required this.currentPath,
    required this.onNavigate,
    super.key,
  });

  final String currentPath;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(deviceProvider);

    return devicesAsync.when(
      data: (devices) {
        final home = Platform.environment['HOME'] ?? '/';
        final filteredDevices = devices.where((d) {
          final path = d.path;
          final name = d.name.toLowerCase();
          return path != '/' && 
                 path != home && 
                 name != 'home' && 
                 name != 'file system';
        }).toList();
        
        if (filteredDevices.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: filteredDevices.map((device) => SidebarItem(
                icon: Icons.storage_outlined,
                label: device.name,
                path: device.path,
                isActive: (currentPath == device.path) || 
                          (currentPath.startsWith(device.path) && device.path != '/'),
                progress: device.usage,
                onEject: device.isRemovable
                    ? () async {
                        try {
                          // Unmount the block device
                          await Process.run('udisksctl', ['unmount', '-b', device.id]);
                          // Optionally power off/eject for USB drives
                          await Process.run('udisksctl', ['power-off', '-b', device.id]);
                        } catch (e) {
                          debugPrint('Eject error: $e');
                        }
                      }
                    : null,
                onTap: () => onNavigate(device.path),
              )).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Loading devices...', style: TextStyle(color: Colors.white38, fontSize: 10)),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text('Error: $error', style: const TextStyle(color: Colors.red, fontSize: 10)),
      ),
    );
  }
}
