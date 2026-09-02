import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/widgets/onyx_dropdown.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/services/default_extractor_template_service.dart';
import 'package:onyxcore/features/downloader/domain/services/default_extractor_validator.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';

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

class _AddExtractorDialogState extends ConsumerState<AddExtractorDialog> {
  // ── Controllers / state ──────────────────────────────────────────────────

  bool _isScriptMode = false;

  late TextEditingController _nameController;
  late TextEditingController _selectorController;
  late TextEditingController _attributeController;
  late TextEditingController _scriptController;

  String _selectedKind = DefaultExtractorKind.html.name;

  String? _nameError;
  String? _selectorError;
  String? _attributeError;
  String? _scriptBodyError;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    final editing = widget.extractor;
    DefaultExtractorConfig? existingConfig;

    if (editing != null) {
      existingConfig =
          DefaultExtractorTemplateService.decodeMetadata(editing.metadata);
      if (existingConfig == null) {
        _isScriptMode = true;
      }
    }

    _nameController = TextEditingController(text: editing?.name ?? '');
    _scriptController = TextEditingController(text: editing?.script ?? '');
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
    _nameController.dispose();
    _selectorController.dispose();
    _attributeController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _save() {
    if (_isScriptMode) {
      _saveScript();
    } else {
      _saveDefault();
    }
  }

  void _saveDefault() {
    final name = _nameController.text.trim();
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
    final name = _nameController.text.trim();
    final script = _scriptController.text.trim();

    final nameErr = DefaultExtractorValidator.validateExtractorName(name);
    final scriptErr = script.isEmpty ? 'Script cannot be empty.' : null;

    setState(() {
      _nameError = nameErr;
      _scriptBodyError = scriptErr;
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
    final isEditing = widget.extractor != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 600,
        height: 560,
        padding: const EdgeInsets.all(1.5), // For gradient border
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              AppColors.magenta,
              AppColors.violet,
              AppColors.indigo,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit Custom Extractor'
                                : 'Add Custom Extractor',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                          if (isEditing) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Created: ${DateFormat('MMM d, yyyy HH:mm').format(widget.extractor!.createdAt)}  •  Modified: ${DateFormat('MMM d, yyyy HH:mm').format(widget.extractor!.modifiedAt)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isEditing) ...[
                      Row(
                        children: [
                          Text('Script Mode', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          OnyxSwitch(
                            value: _isScriptMode,
                            onChanged: (val) {
                              setState(() => _isScriptMode = val);
                            },
                          ),
                          const SizedBox(width: 16),
                        ],
                      )
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _isScriptMode ? _buildScriptMode() : _buildDefaultMode(),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.magenta,
                            AppColors.violet,
                            AppColors.indigo,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Update' : 'Create',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Default mode ───────────────────────────────────────────────────────────

  Widget _buildDefaultMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CustomInputField(
            label: 'Extractor Name',
            errorText: _nameError,
            child: TextField(
              key: const ValueKey('extractor_name_field'),
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. ABC Image Extractor',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() {
                    _nameError = DefaultExtractorValidator.validateExtractorName(
                      _nameController.text.trim(),
                    );
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          _CustomInputField(
            label: 'Extractor Type',
            isDropdown: true,
            child: OnyxDropdown<String>(
              isExpanded: true,
              value: _selectedKind,
              options: [
                MapEntry(DefaultExtractorKind.html.name, 'HTML Extractor'),
              ],
              onChanged: (val) {
                setState(() => _selectedKind = val);
              },
            ),
          ),
          const SizedBox(height: 16),

          _CustomInputField(
            label: 'CSS Selector',
            errorText: _selectorError,
            child: TextField(
              key: const ValueKey('extractor_selector_field'),
              controller: _selectorController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. .article-content img',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
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
          ),
          const SizedBox(height: 16),

          _CustomInputField(
            label: 'Attribute Name',
            errorText: _attributeError,
            child: TextField(
              key: const ValueKey('extractor_attribute_field'),
              controller: _attributeController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. src, href, data-src',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
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
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Script mode ────────────────────────────────────────────────────────────

  Widget _buildScriptMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _CustomInputField(
          label: 'Extractor Name',
          errorText: _nameError,
          child: TextField(
            key: const ValueKey('extractor_name_script_field'),
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'e.g. My Site Extractor',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onChanged: (val) {
              if (_nameError != null) {
                setState(() {
                  _nameError =
                      DefaultExtractorValidator.validateExtractorName(
                    _nameController.text.trim(),
                  );
                });
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Script',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header for language
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Language',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      OnyxDropdown<String>(
                        value: 'js',
                        options: const [
                          MapEntry('js', 'JavaScript'),
                        ],
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                ),
                // Script content
                Expanded(
                  child: TextField(
                    key: const ValueKey('extractor_script_field'),
                    controller: _scriptController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'async function extract(url) {\n  // document is available.\n  // Return Array<String> of URLs.\n  return [];\n}',
                      hintStyle: const TextStyle(color: Colors.white24, fontFamily: 'monospace'),
                      errorText: _scriptBodyError,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
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
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CustomInputField extends StatelessWidget {
  const _CustomInputField({
    required this.label,
    required this.child,
    this.errorText,
    this.isDropdown = false,
  });

  final String label;
  final Widget child;
  final String? errorText;
  final bool isDropdown;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (isDropdown)
          child
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: errorText != null 
                    ? Colors.red.withValues(alpha: 0.5) 
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: child,
          ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
