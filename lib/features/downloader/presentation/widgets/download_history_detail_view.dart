import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';

class DownloadHistoryDetailView extends ConsumerStatefulWidget {
  const DownloadHistoryDetailView({super.key});

  @override
  ConsumerState<DownloadHistoryDetailView> createState() => _DownloadHistoryDetailViewState();
}

class _DownloadHistoryDetailViewState extends ConsumerState<DownloadHistoryDetailView> {
  bool _logsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entryId = ref.watch(selectedDownloadHistoryIdProvider);
    if (entryId == null) {
      return const SizedBox();
    }
    
    final entry = ref.watch(downloadHistoryProvider.notifier).getEntry(entryId);
    if (entry == null) {
      return Center(child: Text('History not found', style: GoogleFonts.manrope(color: Colors.white)));
    }

    final isSuccess = entry.statusName.toLowerCase() == 'completed';
    final isError = entry.statusName.toLowerCase() == 'error';

    Color statusColor = Colors.white54;
    IconData statusIcon = Icons.info_outline;
    if (isSuccess) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (isError) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_outline_rounded;
    } else if (entry.statusName.toLowerCase() == 'cancelled') {
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.cancel_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white70),
                onPressed: () {
                  ref.read(selectedDownloadHistoryIdProvider.notifier).state = null;
                  ref.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.history;
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Download Details',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                tooltip: 'Delete History',
                onPressed: () {
                  ref.read(downloadHistoryProvider.notifier).deleteEntry(entryId);
                  ref.read(selectedDownloadHistoryIdProvider.notifier).state = null;
                  ref.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.history;
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.statusName.toUpperCase(),
                            style: GoogleFonts.manrope(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.link_rounded, 'Source URL', entry.url),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.folder_open_rounded, 'Destination', entry.destination, isPath: true),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.schedule_rounded, 'Started', entry.createdAt.toString()),
                      if (entry.completedAt != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.task_alt_rounded, 'Completed', entry.completedAt.toString()),
                      ],
                      if (entry.errorMessage != null && entry.errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(Icons.error_outline_rounded, 'Error', entry.errorMessage!, color: Colors.redAccent),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                // Logs
                if (entry.logs.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _logsExpanded = !_logsExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _logsExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Process Logs',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_logsExpanded)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: SelectableText(
                        entry.logs.join('\n'),
                        style: GoogleFonts.firaCode(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isPath = false, Color color = Colors.white70}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.5)),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: color.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: isPath 
            ? InkWell(
                onTap: () {
                  if (Directory(value).existsSync()) {
                    ref.read(navigationProvider.notifier).navigateTo(value);
                  }
                },
                child: Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: AppColors.violet,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.violet.withOpacity(0.5),
                  ),
                ),
              )
            : SelectableText(
                value,
                style: GoogleFonts.manrope(
                  color: color,
                  fontSize: 12,
                ),
              ),
        ),
      ],
    );
  }
}
