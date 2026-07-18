import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/platform/disk_usage.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';

/// Real disk usage storage indicator — pixel-perfect match of original _buildStorageIndicator().
class StorageIndicator extends ConsumerStatefulWidget {
  const StorageIndicator({super.key});

  @override
  ConsumerState<StorageIndicator> createState() => _StorageIndicatorState();
}

class _StorageIndicatorState extends ConsumerState<StorageIndicator> {
  DiskUsage? _usage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUsage();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loadUsage());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUsage() async {
    final home = Platform.environment['HOME'] ?? '/';
    final usage = await getDiskUsage(home);
    if (mounted) setState(() => _usage = usage);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshCountProvider, (_, __) => _loadUsage());
    final usage = _usage;
    final fraction = usage?.usageFraction ?? 0.6;
    final percentLabel = usage?.usagePercent ?? '60%';
    final usedLabel = usage?.usedHuman ?? '1.2 TB';
    final totalLabel = usage?.totalHuman ?? '2.0 TB';
    final availableLabel = usage?.availableHuman ?? '';
    
    var formattedUsage = '$usedLabel of $totalLabel';
    try {
      final parts = totalLabel.split(' ');
      if (parts.length == 2) {
        final total = double.parse(parts[0]);
        final used = total * fraction;
        formattedUsage = '${used.toStringAsFixed(1)} / $totalLabel';
      }
    } catch (_) {}
    
    final subtitleText = availableLabel.isNotEmpty
        ? '$formattedUsage  •  Free: $availableLabel'
        : formattedUsage;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM STORAGE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.3),
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                percentLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitleText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
