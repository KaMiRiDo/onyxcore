import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/device.dart';
import 'package:onyxcore/core/utils/logger.dart';

/// StreamProvider that polls for connected storage devices every 2 seconds.
final deviceProvider = StreamProvider<List<Device>>((ref) {
  final controller = StreamController<List<Device>>();
  final Set<String> attemptedMounts = {};
  
  Timer? timer;

  Future<void> autoMount(String deviceId) async {
    try {
      log('Auto-mounting $deviceId...');
      await Process.run('udisksctl', ['mount', '-b', deviceId]);
    } catch (e) {
      log('Auto-mount error for $deviceId: $e');
    }
  }

  Future<void> updateDevices() async {
    try {
      // Use --bytes for raw sizes, -p for full paths, --json for easy parsing
      final result = await Process.run('lsblk', [
        '--json', 
        '--bytes',
        '-p',
        '-o', 'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,TYPE,LABEL,MODEL,RM,FSTYPE'
      ]);
      
      if (result.exitCode != 0) {
        if (!controller.isClosed) controller.add([]);
        return;
      }

      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final List<Device> devices = [];

      final Set<String> currentIds = {};
      void parseDevices(List<dynamic> list) {
        for (var item in list) {
          final deviceId = item['name']?.toString() ?? '';
          if (deviceId.isNotEmpty) currentIds.add(deviceId);

          final mountpoint = item['mountpoint'] as String?;
          final fssizeStr = item['fssize']?.toString();
          final fsusedStr = item['fsused']?.toString();
          final fstype = item['fstype']?.toString() ?? '';
          final isRemovable = (item['rm'] == true || item['rm'] == 1 || item['rm'] == "1");

          final mp = mountpoint?.trim() ?? '';
          final rawSize = double.tryParse(item['size']?.toString() ?? '0') ?? 0;

          // Filter for meaningful user partitions/disks
          final isMounted = mp.isNotEmpty;
          final hasChildren = item['children'] != null && (item['children'] as List).isNotEmpty;

          // Auto-mount removable drives if they are not mounted and have no children (actual partitions)
          if (isRemovable && !isMounted && !hasChildren && fstype != 'swap') {
            if (!attemptedMounts.contains(deviceId)) {
              attemptedMounts.add(deviceId);
              autoMount(deviceId);
            }
          }

          if (!mp.startsWith('/snap') && !mp.startsWith('/boot') && mp != '[SWAP]' && fstype != 'swap') {
            // Only show mounted volumes in the UI
            if (isMounted) {
            
            double usage = 0.0;
            if (fssizeStr != null && fsusedStr != null) {
              final used = double.tryParse(fsusedStr) ?? 0.0;
              final total = double.tryParse(fssizeStr) ?? 0.0;
              if (total > 0) usage = (used / total).clamp(0.0, 1.0);
            }

            final formattedSize = _formatSize(rawSize);

            String displayName;
            final label = item['label']?.toString();
            final model = item['model']?.toString();

            if (mp == '/') {
              displayName = 'File System';
            } else if (mp == '/home' || mp.startsWith('/home/') || mp.contains('/home/')) {
              if (mp == '/home') {
                displayName = 'Home';
              } else {
                displayName = 'Home Partition';
              }
            } else if (label != null && label.trim().isNotEmpty) {
              displayName = label.trim();
            } else if (model != null && model.trim().isNotEmpty) {
              displayName = model.trim();
            } else {
              displayName = '$formattedSize Volume';
            }

            if (!hasChildren) {
              devices.add(Device(
                id: deviceId,
                name: displayName,
                path: mp, 
                size: formattedSize,
                usage: usage,
                isRemovable: isRemovable || mp.startsWith('/media') || mp.startsWith('/run/media'),
              ));
            }
            }
          }

          if (item['children'] != null) {
            parseDevices(item['children'] as List<dynamic>);
          }
        }
      }

      if (data['blockdevices'] != null) {
        parseDevices(data['blockdevices'] as List<dynamic>);
      }

      // Cleanup attemptedMounts: remove IDs that are no longer in the system
      attemptedMounts.retainAll(currentIds);

      // Sort devices: File System (/), Home (/home), then others
      devices.sort((a, b) {
        if (a.path == '/') return -1;
        if (b.path == '/') return 1;
        if (a.path == '/home') return -1;
        if (b.path == '/home') return 1;
        return a.name.compareTo(b.name);
      });

      if (!controller.isClosed) controller.add(devices);
    } catch (e) {
      log('Error detecting devices: $e');
      if (!controller.isClosed) controller.add([]);
    }
  }

  // Initial update
  updateDevices();

  // Poll every 2 seconds
  timer = Timer.periodic(const Duration(seconds: 2), (_) => updateDevices());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

String _formatSize(double bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var i = 0;
  while (bytes >= 1024 && i < suffixes.length - 1) {
    bytes /= 1024;
    i++;
  }
  return '${bytes.toStringAsFixed(1)} ${suffixes[i]}';
}
