import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onyxcore/core/utils/browser_detector.dart';
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

    final dropdownEntries = _browsers!.map((b) {
      final isSupported = b.capability == BrowserCapability.chromium;
      var label = b.name;
      if (b.id == _defaultBrowser) {
        label += ' (Default)';
      }
      if (!isSupported) {
        label += ' (Not Supported Yet)';
      }

      return DropdownMenuItem<String>(
        value: b.id,
        enabled: isSupported,
        child: Text(label),
      );
    }).toList();

    return ListTile(
      title: const Text('Custom Extractor Browser'),
      subtitle: const Text(
          'Select the Chromium-based browser to use for Custom Extractors.'),
      trailing: DropdownButton<String>(
        value: _browsers!.any((b) => b.id == selected) ? selected : null,
        hint: const Text('Select Browser'),
        items: dropdownEntries,
        onChanged: (value) {
          if (value != null) {
            ref.read(settingsProvider.notifier).setExtractorBrowser(value);
          }
        },
      ),
    );
  }
}
