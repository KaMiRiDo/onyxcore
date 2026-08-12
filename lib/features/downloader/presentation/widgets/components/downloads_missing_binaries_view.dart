import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloader_readiness_provider.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';

class DownloadsMissingBinariesView extends ConsumerWidget {
  const DownloadsMissingBinariesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(downloaderUpdateProvider);

    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.download_rounded, size: 48, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'Missing Required Dependencies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'OnyxCore requires some external binaries (like yt-dlp and Deno) to download media. Please install them to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (updateState.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  updateState.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            if (updateState.isUpdating) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: updateState.progress,
                  minHeight: 12,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                updateState.currentUpdatingEngineName != null
                    ? 'Installing ${updateState.currentUpdatingEngineName}... ${(updateState.progress * 100).toInt()}%'
                    : 'Installing... ${(updateState.progress * 100).toInt()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(downloaderUpdateProvider.notifier).updateBinaries();
                  await ref.read(downloaderReadinessProvider.notifier).retry();
                },
                icon: const Icon(Icons.download),
                label: const Text('Install Dependencies'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
