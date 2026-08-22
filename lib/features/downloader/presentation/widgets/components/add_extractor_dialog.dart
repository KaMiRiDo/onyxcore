import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/services/default_extractor_template_service.dart';
import 'package:onyxcore/features/downloader/domain/services/default_extractor_validator.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';

// ── Tab indices ──────────────────────────────────────────────────────────────

const int _kDefaultTab = 0;
const int _kScriptTab = 1;

// ── Dialog ───────────────────────────────────────────────────────────────────

class AddExtractorDialog extends ConsumerStatefulWidget {
  const AddExtractorDialog({super.key, this.extractor});

  /// If non-null the dialog is in edit mode and will pre-populate its fields
  /// from this extractor.
  final CustomExtractor? extractor;

  @override
  ConsumerState<AddExtractorDialog> createState() =>
      _AddExtractorDialogState();
}

class _AddExtractorDialogState extends ConsumerState<AddExtractorDialog>
    with SingleTickerProviderStateMixin {
  // ── Controllers / state ──────────────────────────────────────────────────

  late TabController _tabController;

  // Separate name controllers per tab to prevent GlobalKey conflicts when
  // TabBarView renders both pages simultaneously. They are kept in sync.
  late TextEditingController _nameDefaultController;
  late TextEditingController _nameScriptController;

  // Default tab fields
  late TextEditingController _selectorController;
  late TextEditingController _attributeController;
  String _selectedKind = DefaultExtractorKind.html.name;

  // Script tab field
  late TextEditingController _scriptController;

  // Inline validation errors (null = no error)
  String? _nameError;
  String? _selectorError;
  String? _attributeError;
  String? _scriptNameError;
  String? _scriptBodyError;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Determine which tab to open based on the extractor being edited.
    final editing = widget.extractor;
    DefaultExtractorConfig? existingConfig;
    var initialTab = _kDefaultTab;

    if (editing != null) {
      existingConfig =
          DefaultExtractorTemplateService.decodeMetadata(editing.metadata);
      // If metadata is absent or unrecognised → this is a script extractor.
      if (existingConfig == null) {
        initialTab = _kScriptTab;
      }
    }

    _tabController = TabController(length: 2, vsync: this)
      ..index = initialTab;

    final initialName = editing?.name ?? '';
    // Separate controllers to avoid GlobalKey conflicts in TabBarView.
    _nameDefaultController = TextEditingController(text: initialName);
    _nameScriptController = TextEditingController(text: initialName);

    // Keep the two name controllers in sync bidirectionally.
    _nameDefaultController.addListener(() {
      if (_nameScriptController.text != _nameDefaultController.text) {
        _nameScriptController.text = _nameDefaultController.text;
      }
    });
    _nameScriptController.addListener(() {
      if (_nameDefaultController.text != _nameScriptController.text) {
        _nameDefaultController.text = _nameScriptController.text;
      }
    });

    _scriptController =
        TextEditingController(text: editing?.script ?? '');

    // Pre-populate default extractor fields from decoded metadata
    _selectorController =
        TextEditingController(text: existingConfig?.cssSelector ?? '');
    _attributeController =
        TextEditingController(text: existingConfig?.attributeName ?? '');
    if (existingConfig != null) {
      _selectedKind = existingConfig.kind.name;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameDefaultController.dispose();
    _nameScriptController.dispose();
    _selectorController.dispose();
    _attributeController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _saveDefault() {
    final name = _nameDefaultController.text.trim();
    final selector = _selectorController.text.trim();
    final attribute = _attributeController.text.trim();

    final nameErr = DefaultExtractorValidator.validateExtractorName(name);
    final selectorErr =
        DefaultExtractorValidator.validateCssSelector(selector);
    final attributeErr =
        DefaultExtractorValidator.validateAttributeName(attribute);

    setState(() {
      _nameError = nameErr;
      _selectorError = selectorErr;
      _attributeError = attributeErr;
    });

    if (nameErr != null || selectorErr != null || attributeErr != null) return;

    // Build config from the selected kind.
    final kind = DefaultExtractorKind.values
        .firstWhere((k) => k.name == _selectedKind);
    final config = DefaultExtractorConfig(
      kind: kind,
      cssSelector: selector,
      attributeName: attribute,
    );

    const service = DefaultExtractorTemplateService();
    final script = service.generateScript(config);
    final metadata = DefaultExtractorTemplateService.encodeMetadata(config);

    _persist(name: name, script: script, metadata: metadata);
  }

  void _saveScript() {
    final name = _nameScriptController.text.trim();
    final script = _scriptController.text.trim();

    final nameErr = DefaultExtractorValidator.validateExtractorName(name);
    final scriptErr = script.isEmpty ? 'Script cannot be empty.' : null;

    setState(() {
      _scriptNameError = nameErr;
      _scriptBodyError = scriptErr;
      // Also surface name error in the name field
      _nameError = nameErr;
    });

    if (nameErr != null || scriptErr != null) return;

    _persist(name: name, script: script);
  }

  void _persist({
    required String name,
    required String script,
    String? metadata,
  }) {
    if (widget.extractor != null) {
      final updated = widget.extractor!.copyWith(
        name: name,
        script: script,
        modifiedAt: DateTime.now(),
        metadata: metadata,
      );
      ref.read(customExtractorsProvider.notifier).updateExtractor(updated);
    } else {
      final newExtractor = CustomExtractor(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        script: script,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        metadata: metadata,
      );
      ref.read(customExtractorsProvider.notifier).addExtractor(newExtractor);
    }

    Navigator.of(context).pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.extractor == null
            ? 'Add Custom Extractor'
            : 'Edit Custom Extractor',
      ),
      content: SizedBox(
        width: 600,
        height: 460,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Default Extractor'),
                Tab(text: 'Script'),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDefaultTab(),
                  _buildScriptTab(),
                ],
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
          onPressed: () {
            if (_tabController.index == _kDefaultTab) {
              _saveDefault();
            } else {
              _saveScript();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  // ── Default tab ───────────────────────────────────────────────────────────

  Widget _buildDefaultTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Extractor Name
          TextField(
            key: const ValueKey('extractor_name_field'),
            controller: _nameDefaultController,
            decoration: InputDecoration(
              labelText: 'Extractor Name',
              hintText: 'e.g. ABC Image Extractor',
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) {
                setState(() {
                  _nameError = DefaultExtractorValidator.validateExtractorName(
                    _nameDefaultController.text.trim(),
                  );
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Extractor Type (dropdown — extensible for future kinds)
          DropdownButtonFormField<String>(
            value: _selectedKind,
            decoration: const InputDecoration(
              labelText: 'Extractor Type',
            ),
            items: [
              DropdownMenuItem(
                value: DefaultExtractorKind.html.name,
                child: const Text('HTML Extractor'),
              ),
              // Future extractor kinds are added here.
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedKind = val);
            },
          ),
          const SizedBox(height: 16),

          // CSS Selector
          TextField(
            key: const ValueKey('extractor_selector_field'),
            controller: _selectorController,
            decoration: InputDecoration(
              labelText: 'CSS Selector',
              hintText: 'e.g. .article-content img',
              errorText: _selectorError,
            ),
            onChanged: (_) {
              if (_selectorError != null) {
                setState(() {
                  _selectorError =
                      DefaultExtractorValidator.validateCssSelector(
                    _selectorController.text.trim(),
                  );
                });
              }
            },
          ),
          const SizedBox(height: 16),

          // Attribute Name
          TextField(
            key: const ValueKey('extractor_attribute_field'),
            controller: _attributeController,
            decoration: InputDecoration(
              labelText: 'Attribute Name',
              hintText: 'e.g. src, href, data-src',
              errorText: _attributeError,
            ),
            onChanged: (_) {
              if (_attributeError != null) {
                setState(() {
                  _attributeError =
                      DefaultExtractorValidator.validateAttributeName(
                    _attributeController.text.trim(),
                  );
                });
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Script tab ────────────────────────────────────────────────────────────

  Widget _buildScriptTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Extractor Name (separate controller, kept in sync with Default tab)
        TextField(
          key: const ValueKey('extractor_name_script_field'),
          controller: _nameScriptController,
          decoration: InputDecoration(
            labelText: 'Extractor Name',
            hintText: 'e.g. My Site Extractor',
            errorText: _scriptNameError,
          ),
          onChanged: (val) {
            _nameDefaultController.text = val;
            if (_scriptNameError != null) {
              setState(() {
                _scriptNameError =
                    DefaultExtractorValidator.validateExtractorName(
                  _nameScriptController.text.trim(),
                );
              });
            }
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TextField(
            key: const ValueKey('extractor_script_field'),
            controller: _scriptController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: 'JavaScript Script',
              alignLabelWithHint: true,
              hintText:
                  'async function extract(url) {\n  // document is available.\n  // Return Array<String> of URLs.\n  return [];\n}',
              errorText: _scriptBodyError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_scriptBodyError != null) {
                setState(() {
                  _scriptBodyError = _scriptController.text.trim().isEmpty
                      ? 'Script cannot be empty.'
                      : null;
                });
              }
            },
          ),
        ),
      ],
    );
  }
}
