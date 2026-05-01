import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/device.dart';
import 'package:onyxcore/core/utils/logger.dart';

/// StreamProvider that polls for connected storage devices every 2 seconds.
final deviceProvider = StreamProvider<List<Device>>((ref) {
  final controller = StreamController<List<Device>>();
  
  Timer? timer;

  Future<void> updateDevices() async {
    try {
      // Use --bytes for raw sizes, -p for full paths, --json for easy parsing
      final result = await Process.run('lsblk', [
        '--json', 
        '--bytes',
        '-p',
        '-o', 'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,TYPE,LABEL,MODEL,RM'
      ]);
      
      if (result.exitCode != 0) {
        if (!controller.isClosed) controller.add([]);
        return;
      }

      final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final List<Device> devices = [];

      void parseDevices(List<dynamic> list) {
        for (var item in list) {
          final mountpoint = item['mountpoint'] as String?;
          final name = (item['label'] ?? item['model'] ?? item['name'] ?? 'Unknown Device') as String;
          final fssizeStr = item['fssize']?.toString();
          final fsusedStr = item['fsused']?.toString();
          final isRemovable = (item['rm'] == true || item['rm'] == 1 || item['rm'] == "1");

          // Filter for meaningful user partitions/disks that are mounted
          if (mountpoint != null && 
              !mountpoint.startsWith('/snap') && 
              mountpoint != '[SWAP]') {
            
            double usage = 0.0;
            if (fssizeStr != null && fsusedStr != null) {
              final used = double.tryParse(fsusedStr) ?? 0.0;
              final total = double.tryParse(fssizeStr) ?? 0.0;
              if (total > 0) usage = (used / total).clamp(0.0, 1.0);
            }

            String displayName = name;
            final mp = mountpoint.trim();
            
            if (mp == '/') {
              displayName = 'File System';
            } else if (mp == '/home' || mp.startsWith('/home/') || mp.contains('/home/')) {
              // Usually we don't want to show home separately if it's part of the main FS,
              // but if it's a separate mount, we can show it as 'Home'.
              if (mp == '/home') displayName = 'Home';
            } else if (item['label'] != null && (item['label'] as String).isNotEmpty) {
              displayName = item['label'] as String;
            }

            devices.add(Device(
              id: (item['name'] ?? '') as String,
              name: displayName,
              path: mountpoint,
              size: _formatSize(double.tryParse(item['size']?.toString() ?? '0') ?? 0),
              usage: usage,
              isRemovable: isRemovable || mountpoint.startsWith('/media') || mountpoint.startsWith('/run/media'),
            ));
          }

          if (item['children'] != null) {
            parseDevices(item['children'] as List<dynamic>);
          }
        }
      }

      if (data['blockdevices'] != null) {
        parseDevices(data['blockdevices'] as List<dynamic>);
      }

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
