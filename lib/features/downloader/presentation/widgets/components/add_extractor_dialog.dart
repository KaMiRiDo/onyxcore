import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';

class AddExtractorDialog extends ConsumerStatefulWidget {

  const AddExtractorDialog({super.key, this.extractor});
  final CustomExtractor? extractor;

  @override
  ConsumerState<AddExtractorDialog> createState() => _AddExtractorDialogState();
}

class _AddExtractorDialogState extends ConsumerState<AddExtractorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _scriptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.extractor?.name ?? '');
    _scriptController = TextEditingController(text: widget.extractor?.script ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final script = _scriptController.text.trim();

    if (name.isEmpty || script.isEmpty) return;

    if (widget.extractor != null) {
      final updated = widget.extractor!.copyWith(
        name: name,
        script: script,
        modifiedAt: DateTime.now(),
      );
      ref.read(customExtractorsProvider.notifier).updateExtractor(updated);
    } else {
      final newExtractor = CustomExtractor(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        script: script,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      ref.read(customExtractorsProvider.notifier).addExtractor(newExtractor);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.extractor == null ? 'Add Custom Extractor' : 'Edit Custom Extractor'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Extractor Name',
                hintText: 'e.g. My Site Extractor',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _scriptController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'JavaScript Script',
                  alignLabelWithHint: true,
                  hintText: 'Deno.args[0] contains the URL...\nconsole.log(JSON.stringify([{url: "..."}]))',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
