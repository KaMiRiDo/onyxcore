import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar_item.dart';
import 'dart:io';
import 'dart:async';

class DevicesSection extends ConsumerStatefulWidget {
  const DevicesSection({
    required this.currentPath,
    required this.onNavigate,
    super.key,
  });

  final String currentPath;
  final void Function(String) onNavigate;

  @override
  ConsumerState<DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends ConsumerState<DevicesSection> {
  final Map<String, String> _waitingToEject = {}; // path -> name
  final Map<String, Map<String, dynamic>> _busyDevices =
      {}; // deviceId -> {name, mountPath, startTime}
  final Set<String> _isEjecting = {}; // device.id
  Timer? _busyTimer;

  @override
  void dispose() {
    _busyTimer?.cancel();
    super.dispose();
  }

  void _startBusyCheck() {
    _busyTimer?.cancel();
    _busyTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_busyDevices.isEmpty) {
        timer.cancel();
        _busyTimer = null;
        return;
      }

      final now = DateTime.now();
      final toRemove = <String>[];

      final entries = _busyDevices.entries.toList();
      for (final entry in entries) {
        final deviceId = entry.key;
        final data = entry.value;
        final deviceName = data['name'] as String;
        final mountPath = data['mountPath'] as String;
        final startTime = data['startTime'] as DateTime;

        // 1. Check for 15-minute timeout
        if (now.difference(startTime).inMinutes >= 15) {
          toRemove.add(deviceId);
          continue;
        }

        try {
          // 2. Use 'fuser' to check if any processes are using the mount point
          // Exit code 1 means no processes found (i.e., not busy)
          final fuserRes = await Process.run('fuser', ['-m', mountPath]);
          if (fuserRes.exitCode != 0) {
            // Device is no longer busy!
            toRemove.add(deviceId);
            if (mounted) {
              _showStyledSnackBar(
                context,
                'Now it is safe to eject $deviceName.',
                isSuccess: true,
              );
            }
          }
        } catch (e) {
          debugPrint('Busy check error: $e');
        }
      }

      if (toRemove.isNotEmpty) {
        setState(() {
          for (final id in toRemove) {
            _busyDevices.remove(id);
          }
        });
      }
    });
  }

  void _navigateToPreviouslyVisitedIfEjected(String devicePath) {
    if (widget.currentPath.startsWith(devicePath)) {
      final navNotifier = ref.read(navigationProvider.notifier);
      final lastValidPath = navNotifier.handleEject(devicePath);

      if (lastValidPath != null) {
        ref.read(currentPathProvider.notifier).state = lastValidPath;
      } else {
        // Fallback to HOME if no valid history found
        final home = Platform.environment['HOME'] ?? '/';
        widget.onNavigate(home);
      }
    }
  }

  void _showStyledSnackBar(
    BuildContext context,
    String message, {
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    IconData iconData = Icons.info_outline_rounded;
    Color iconColor = AppColors.violet;

    if (isSuccess) {
      iconData = Icons.check_circle_rounded;
      iconColor = AppColors.success;
    } else if (isWarning) {
      iconData = Icons.warning_amber_rounded;
      iconColor = Colors.orangeAccent;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E26),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _hasActiveTasksForDevice(List<FileTask> tasks, String devicePath) {
    return tasks.any((task) {
      if (task.status != FileTaskStatus.running &&
          task.status != FileTaskStatus.pending) {
        return false;
      }
      final hasTarget = task.targetPath?.startsWith(devicePath) == true;
      final hasSource =
          task.sourcePaths?.any((p) => p.startsWith(devicePath)) == true;
      return hasTarget || hasSource;
    });
  }

  String _formatUsageString(double usage, String totalSizeStr) {
    if (usage <= 0 || totalSizeStr == '0 B') return totalSizeStr;

    try {
      final parts = totalSizeStr.split(' ');
      if (parts.length != 2) return totalSizeStr;

      final total = double.parse(parts[0]);
      final suffix = parts[1];
      final used = total * usage;

      return '${used.toStringAsFixed(1)} / $totalSizeStr';
    } catch (_) {
      return totalSizeStr;
    }
  }

  String _getFreeSpaceString(double usage, String totalSizeStr) {
    if (usage <= 0 || totalSizeStr == '0 B') return totalSizeStr;
    try {
      final parts = totalSizeStr.split(' ');
      if (parts.length != 2) return totalSizeStr;

      final total = double.parse(parts[0]);
      final suffix = parts[1];
      final free = total * (1.0 - usage);

      return '${free.toStringAsFixed(1)} $suffix';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<FileTask>>(taskProvider, (previous, next) {
      if (_waitingToEject.isEmpty) return;

      final completedPaths = <String>[];

      for (final entry in _waitingToEject.entries) {
        final path = entry.key;
        final name = entry.value;
        if (!_hasActiveTasksForDevice(next, path)) {
          completedPaths.add(path);
          if (mounted) {
            _showStyledSnackBar(
              context,
              'Now it is safe to eject $name.',
              isSuccess: true,
            );
          }
        }
      }

      for (final path in completedPaths) {
        _waitingToEject.remove(path);
      }
    });

    final devicesAsync = ref.watch(deviceProvider);

    return devicesAsync.when(
      data: (devices) {
        final home = Platform.environment['HOME'] ?? '/';
        final filteredDevices = devices.where((d) {
          final path = d.path;
          // Only filter out the core root / if we really want to, but the user requested all volumes.
          // We will keep it simple and just show all volumes that lsblk found.
          return true;
        }).toList();

        if (filteredDevices.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: filteredDevices.map((device) {
            final storageText = _formatUsageString(device.usage, device.size);
            final freeSpaceText = _getFreeSpaceString(device.usage, device.size);
            
            final displayStorageText = freeSpaceText.isNotEmpty 
                ? '$storageText  •  Free: $freeSpaceText'
                : storageText;

            return SidebarItem(
              icon: device.isMobile
                  ? Icons.smartphone_rounded
                  : Icons.storage_outlined,
              label: device.name,
              path: device.path,
              isActive:
                  (widget.currentPath == device.path) ||
                  (widget.currentPath.startsWith(device.path) &&
                      device.path != '/'),
              progress: device.usage,
              storageText: displayStorageText,
              onEject: device.isRemovable
                  ? () async {
                      if (_isEjecting.contains(device.id)) return;
                      if (_busyDevices.containsKey(device.id) ||
                          _waitingToEject.containsKey(device.path)) {
                        if (mounted) {
                          _showStyledSnackBar(
                            context,
                            '${device.name} is busy. Will notify when safe to eject.',
                            isWarning: true,
                          );
                        }
                        return;
                      }

                      final tasks = ref.read(taskProvider);
                      if (_hasActiveTasksForDevice(tasks, device.path)) {
                        setState(() {
                          _waitingToEject[device.path] = device.name;
                        });
                        if (mounted) {
                          _showStyledSnackBar(
                            context,
                            'Operations are still running on ${device.name}. Please wait.',
                            isWarning: true,
                          );
                        }
                        return;
                      }

                      setState(() {
                        _isEjecting.add(device.id);
                      });

                      try {
                        ProcessResult unmountRes;
                        final isGvfs = device.path.contains('/gvfs/');

                        if (isGvfs) {
                          unmountRes = await Process.run('gio', [
                            'mount',
                            '-u',
                            device.path,
                          ]);
                        } else {
                          unmountRes = await Process.run('udisksctl', [
                            'unmount',
                            '-b',
                            device.id,
                          ]);
                        }

                        if (unmountRes.exitCode != 0) {
                          final stderr = unmountRes.stderr
                              .toString()
                              .toLowerCase();
                          if (stderr.contains('busy')) {
                            setState(() {
                              _busyDevices[device.id] = {
                                'name': device.name,
                                'mountPath': device.path,
                                'startTime': DateTime.now(),
                              };
                            });
                            _startBusyCheck();
                            if (mounted) {
                              _showStyledSnackBar(
                                context,
                                '${device.name} is busy. Will notify when safe to eject.',
                                isWarning: true,
                              );
                            }
                            return;
                          } else {
                            if (mounted) {
                              _showStyledSnackBar(
                                context,
                                'Failed to eject ${device.name}.',
                                isWarning: true,
                              );
                            }
                            return;
                          }
                        }

                        if (!isGvfs) {
                          await Process.run('udisksctl', [
                            'power-off',
                            '-b',
                            device.id,
                          ]);
                        }
                        _navigateToPreviouslyVisitedIfEjected(device.path);
                        if (mounted) {
                          _showStyledSnackBar(
                            context,
                            '${device.name} safely ejected.',
                            isSuccess: true,
                          );
                        }
                      } catch (e) {
                        debugPrint('Eject error: $e');
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isEjecting.remove(device.id);
                          });
                        }
                      }
                    }
                  : null,
              onTap: () async {
                if (device.path.isEmpty) {
                  if (mounted) {
                    _showStyledSnackBar(context, 'Mounting ${device.name}...');
                  }
                  try {
                    final mountRes = await Process.run('udisksctl', [
                      'mount',
                      '-b',
                      device.id,
                    ]);
                    if (mountRes.exitCode != 0) {
                      if (mounted) {
                        _showStyledSnackBar(
                          context,
                          'Failed to mount: ${mountRes.stderr}',
                        );
                      }
                    } else {
                      if (mounted) {
                        _showStyledSnackBar(
                          context,
                          '${device.name} mounted successfully.',
                          isSuccess: true,
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('Mount error: $e');
                  }
                } else {
                  widget.onNavigate(device.path);
                }
              },
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Loading devices...',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red, fontSize: 10),
        ),
      ),
    );
  }
}
