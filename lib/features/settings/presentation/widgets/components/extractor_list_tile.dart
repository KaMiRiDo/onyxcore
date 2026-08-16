import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/add_extractor_dialog.dart';

class ExtractorListTile extends ConsumerWidget {
  const ExtractorListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extractorsState = ref.watch(customExtractorsProvider);

    return extractorsState.when(
      data: (extractors) {
        if (extractors.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No custom extractors added yet.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: extractors.length,
          itemBuilder: (context, index) {
            final extractor = extractors[index];
            final dateFormat = DateFormat('MMM d, yyyy HH:mm');
            
            return ListTile(
              title: Text(extractor.name),
              subtitle: Text('Created: ${dateFormat.format(extractor.createdAt)}\nModified: ${dateFormat.format(extractor.modifiedAt)}'),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AddExtractorDialog(extractor: extractor),
                      );
                    },
                    tooltip: 'Edit Extractor',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: () async {
                      // TODO: Show confirmation dialog
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Extractor?'),
                          content: Text('Are you sure you want to delete "${extractor.name}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm ?? false) {
                        unawaited(ref.read(customExtractorsProvider.notifier).deleteExtractor(extractor.id));
                      }
                    },
                    tooltip: 'Delete Extractor',
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading extractors: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
