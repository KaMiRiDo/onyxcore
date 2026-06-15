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
  bool _isUpdating = false;

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
    if (_isUpdating) return;
    _isUpdating = true;
    try {
      // Use --bytes for raw sizes, -p for full paths, --json for easy parsing
      final result =
          await Process.run('lsblk', [
            '--json',
            '--bytes',
            '-p',
            '-o',
            'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,FSAVAIL,TYPE,LABEL,MODEL,RM,FSTYPE',
          ]).timeout(
            const Duration(milliseconds: 800),
            onTimeout: () => ProcessResult(0, 1, '', ''),
          );

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
          final fsavailStr = item['fsavail']?.toString();
          final fstype = item['fstype']?.toString() ?? '';
          final isRemovable =
              (item['rm'] == true || item['rm'] == 1 || item['rm'] == "1");

          final mp = mountpoint?.trim() ?? '';
          final rawSize = double.tryParse(item['size']?.toString() ?? '0') ?? 0;

          // Filter for meaningful user partitions/disks
          final isMounted = mp.isNotEmpty;
          final hasChildren =
              item['children'] != null && (item['children'] as List).isNotEmpty;

          // Auto-mount removable drives if they are not mounted and have no children (actual partitions)
          if (isRemovable && !isMounted && !hasChildren && fstype != 'swap') {
            if (!attemptedMounts.contains(deviceId)) {
              attemptedMounts.add(deviceId);
              autoMount(deviceId);
            }
          }

          if (!mp.startsWith('/snap') &&
              !mp.startsWith('/boot') &&
              mp != '[SWAP]' &&
              fstype != 'swap') {
            // Only show mounted volumes in the UI
            if (isMounted) {
              double usage = 0.0;
              if (fsavailStr != null && fsusedStr != null) {
                final used = double.tryParse(fsusedStr) ?? 0.0;
                final avail = double.tryParse(fsavailStr) ?? 0.0;
                final totalUsable = used + avail;
                if (totalUsable > 0)
                  usage = (used / totalUsable).clamp(0.0, 1.0);
              } else if (fssizeStr != null && fsusedStr != null) {
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
              } else if (mp == '/home' ||
                  mp.startsWith('/home/') ||
                  mp.contains('/home/')) {
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
                devices.add(
                  Device(
                    id: deviceId,
                    name: displayName,
                    path: mp,
                    size: formattedSize,
                    usage: usage,
                    isRemovable:
                        isRemovable ||
                        mp.startsWith('/media') ||
                        mp.startsWith('/run/media'),
                  ),
                );
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

      // Add GVFS mounts (e.g. MTP for mobile devices)
      try {
        final idRes = await Process.run('id', ['-u']);
        final uid = idRes.stdout.toString().trim();
        final gvfsDir = Directory('/run/user/$uid/gvfs');
        if (await gvfsDir.exists()) {
          final entities = await gvfsDir.list().toList();
          for (final entity in entities) {
            if (entity is Directory) {
              final name = entity.path.split('/').last;
              String displayName = name;
              bool isMobile = false;
              if (name.startsWith('mtp:host=')) {
                isMobile = true;
                try {
                  displayName = Uri.decodeComponent(
                    name.substring(9),
                  ).replaceAll('_', ' ');
                } catch (_) {}
              } else if (name.startsWith('gphoto2:host=')) {
                isMobile = true;
                try {
                  displayName = Uri.decodeComponent(
                    name.substring(13),
                  ).replaceAll('_', ' ');
                } catch (_) {}
              } else if (name.startsWith('smb-share:server=')) {
                displayName = 'SMB Share';
              }

              String sizeStr = 'Unknown';
              double usage = 0.0;
              try {
                final dfRes = await Process.run('df', ['-k', entity.path])
                    .timeout(
                      const Duration(milliseconds: 500),
                      onTimeout: () => ProcessResult(0, 1, '', ''),
                    );
                if (dfRes.exitCode == 0) {
                  final lines = dfRes.stdout.toString().trim().split('\n');
                  if (lines.length >= 2) {
                    final parts = lines[1].split(RegExp(r'\s+'));
                    if (parts.length >= 4) {
                      final totalKb = double.tryParse(parts[1]) ?? 0.0;
                      final usedKb = double.tryParse(parts[2]) ?? 0.0;
                      if (totalKb > 0) {
                        sizeStr = _formatSize(totalKb * 1024);
                        usage = (usedKb / totalKb).clamp(0.0, 1.0);
                      }
                    }
                  }
                }
              } catch (_) {}

              devices.add(
                Device(
                  id: name,
                  name: displayName,
                  path: entity.path,
                  size: sizeStr,
                  usage: usage,
                  isRemovable: true,
                  isMobile: isMobile,
                ),
              );
            }
          }
        }
      } catch (e) {
        log('Error checking GVFS mounts: $e');
      }

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
    } finally {
      _isUpdating = false;
    }
  }

  // Initial update
  updateDevices();

  // Poll every 1 second for near-instant UI refreshes
  timer = Timer.periodic(const Duration(seconds: 1), (_) => updateDevices());

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
