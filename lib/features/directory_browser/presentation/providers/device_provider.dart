import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/device.dart';
import 'package:onyxcore/core/utils/logger.dart';

final deviceProvider = FutureProvider<List<Device>>((ref) async {
  try {
    log('Starting device detection...');
    final result = await Process.run('lsblk', ['--json', '-o', 'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,TYPE,LABEL,MODEL']);
    if (result.exitCode != 0) return [];

    final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final List<Device> devices = [];

    void parseDevices(List<dynamic> list) {
      for (var item in list) {
        final mountpoint = item['mountpoint'] as String?;
        final name = (item['label'] ?? item['model'] ?? item['name'] ?? 'Unknown Device') as String;
        final fssize = item['fssize'] as String?;
        final fsused = item['fsused'] as String?;

        // Filter for meaningful user partitions/disks
        if (mountpoint != null && 
            !mountpoint.startsWith('/snap') && 
            mountpoint != '[SWAP]') {
          
          double usage = 0.0;
          if (fssize != null && fsused != null) {
            try {
              final used = _parseSize(fsused);
              final total = _parseSize(fssize);
              if (total > 0) usage = used / total;
            } catch (_) {}
          }

          String displayName = name;
          final mp = mountpoint.trim();
          log('DEBUG: Checking device $name with mountpoint "$mp"');
          
          if (mp == '/') {
            displayName = 'File System';
          } else if (mp == '/home' || mp.startsWith('/home/') || mp.contains('/home/')) {
            displayName = 'Home';
          } else if (item['label'] != null && (item['label'] as String).isNotEmpty) {
            displayName = item['label'] as String;
          }

          log('Adding device: $displayName at $mountpoint (original name: $name)');
          devices.add(Device(
            name: displayName,
            path: mountpoint,
            size: (item['size'] ?? '') as String,
            usage: usage,
            isRemovable: mountpoint.startsWith('/media') || mountpoint.startsWith('/run/media'),
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

    return devices;
  } catch (e) {
    return [];
  }
});

double _parseSize(String sizeStr) {
  final regExp = RegExp(r'^([\d.]+)([KMGTP]?)$');
  final match = regExp.firstMatch(sizeStr.toUpperCase());
  if (match == null) return 0.0;

  final value = double.tryParse(match.group(1)!) ?? 0.0;
  final unit = match.group(2);

  switch (unit) {
    case 'K': return value * 1024;
    case 'M': return value * 1024 * 1024;
    case 'G': return value * 1024 * 1024 * 1024;
    case 'T': return value * 1024 * 1024 * 1024 * 1024;
    case 'P': return value * 1024 * 1024 * 1024 * 1024 * 1024;
    default: return value;
  }
}
