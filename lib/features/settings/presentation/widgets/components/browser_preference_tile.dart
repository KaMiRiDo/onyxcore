import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/core/widgets/onyx_dropdown.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class BrowserPreferenceTile extends ConsumerStatefulWidget {
  const BrowserPreferenceTile({super.key});

  @override
  ConsumerState<BrowserPreferenceTile> createState() =>
      _BrowserPreferenceTileState();
}

class _BrowserPreferenceTileState extends ConsumerState<BrowserPreferenceTile> {
  List<BrowserInfo>? _browsers;
  String? _defaultBrowser;

  @override
  void initState() {
    super.initState();
    _initBrowsers();
  }

  Future<void> _initBrowsers() async {
    final browsers = await BrowserDetector.getExtractorBrowsers();
    final defaultBrowser = await BrowserDetector.getDefaultBrowser();
    if (mounted) {
      setState(() {
        _browsers = browsers;
        _defaultBrowser = defaultBrowser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) {
      return const SizedBox.shrink();
    }

    if (_browsers == null) {
      return const ListTile(
        title: Text('Custom Extractor Browser'),
        subtitle: Text('Loading browsers...'),
      );
    }

    final selected = settings.extractorBrowser ?? _defaultBrowser;



    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Extractor Browser',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the Chromium-based browser to use for Custom Extractors.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 36,
            width: 160,
            child: OnyxDropdown<String>(
              isExpanded: true,
              value: _browsers!.any((b) => b.id == selected) ? selected! : _browsers!.first.id,
              options: _browsers!
                  .map((b) => MapEntry(b.id, b.name))
                  .toList(),
              disabledOptions: _browsers!
                  .where((b) => b.capability != BrowserCapability.chromium)
                  .map((b) => b.id)
                  .toSet(),
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setExtractorBrowser(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
