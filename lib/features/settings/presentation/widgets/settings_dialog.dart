import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/downloader/services/aria2_accelerator.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  final int initialTab;
  final String? initialSection;

  const SettingsDialog({
    this.initialTab = 0,
    this.initialSection,
    super.key,
  });

  static Future<void> show(
    BuildContext context, {
    int initialTab = 0,
    String? section,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) =>
          SettingsDialog(initialTab: initialTab, initialSection: section),
    );
  }

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Scroll controllers for each tab
  final _generalScrollController = ScrollController();
  final _viewersScrollController = ScrollController();
  final _securityScrollController = ScrollController();
  final _shortcutsScrollController = ScrollController();

  // Keys for sections to enable auto-scrolling
  final _generalKeys = {
    'Files & Folders': GlobalKey(),
    'Download Manager': GlobalKey(),
    'Sync': GlobalKey(),
    'Performance': GlobalKey(),
  };
  final _viewersKeys = {
    'Image': GlobalKey(),
    'Video': GlobalKey(),
    'Audio': GlobalKey(),
    'Documents': GlobalKey(),
  };
  final _securityKeys = {
    'Vault': GlobalKey(),
    'Encryption': GlobalKey(),
  };
  final _shortcutsKeys = {
    'General': GlobalKey(),
    'Download Manager': GlobalKey(),
    'Image Viewer': GlobalKey(),
    'Video Player': GlobalKey(),
    'Audio Player': GlobalKey(),
    'Document Viewer': GlobalKey(),
  };

  String _activeGeneralSection = 'Files & Folders';
  String _activeViewersSection = 'Image';
  String _activeSecuritySection = 'Vault';
  String _activeShortcutsSection = 'General';

  late double _width;
  late double _height;
  bool _isResizing = false;

  // Draft state for buffered saving
  AppSettings? _draftSettings;
  AppSettings? _originalSettings;

  List<String> _installedBrowsers = [];
  String? _defaultBrowser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    final settings = ref.read(settingsProvider).value;
    _width = settings?.settingsWidth ?? 760;
    _height = settings?.settingsHeight ?? 560;

    // Handle initial section scrolling
    if (widget.initialSection != null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        final tabName = widget.initialTab == 0
            ? 'General'
            : (widget.initialTab == 1
                  ? 'Viewers/Players'
                  : (widget.initialTab == 2 ? 'Security' : 'Shortcuts'));

        GlobalKey? targetKey;
        if (tabName == 'General')
          targetKey = _generalKeys[widget.initialSection];
        if (tabName == 'Viewers/Players')
          targetKey = _viewersKeys[widget.initialSection];
        if (tabName == 'Security')
          targetKey = _securityKeys[widget.initialSection];
        if (tabName == 'Shortcuts')
          targetKey = _shortcutsKeys[widget.initialSection];

        if (targetKey != null) {
          _scrollToSection(targetKey, widget.initialSection!, tabName);
        }
      });
    }

    _loadBrowsers();
  }

  Future<void> _loadBrowsers() async {
    // Wait for the dialog transition animation to finish before starting processes
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    
    final installed = await BrowserDetector.getInstalledBrowsers();
    final defaultB = await BrowserDetector.getDefaultBrowser();
    if (mounted) {
      setState(() {
        _installedBrowsers = installed;
        _defaultBrowser = defaultB;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _generalScrollController.dispose();
    _viewersScrollController.dispose();
    _securityScrollController.dispose();
    _shortcutsScrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key, String sectionName, String tab) {
    setState(() {
      if (tab == 'General') _activeGeneralSection = sectionName;
      if (tab == 'Viewers/Players') _activeViewersSection = sectionName;
      if (tab == 'Security') _activeSecuritySection = sectionName;
      if (tab == 'Shortcuts') _activeShortcutsSection = sectionName;
    });

    final context = key.currentContext;
    if (context != null) {
      final scrollController = tab == 'General'
          ? _generalScrollController
          : tab == 'Viewers/Players'
          ? _viewersScrollController
          : tab == 'Security'
          ? _securityScrollController
          : _shortcutsScrollController;

      final RenderBox box = context.findRenderObject() as RenderBox;
      final RenderBox? viewport =
          scrollController.position.context.storageContext.findRenderObject()
              as RenderBox?;

      if (viewport != null) {
        final offset = box.localToGlobal(Offset.zero, ancestor: viewport);
        scrollController.animateTo(
          (scrollController.offset + offset.dy).clamp(
            0.0,
            scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      data: (settings) {
        // Initialize draft on first load
        if (_originalSettings == null) {
          _originalSettings = settings;
          _draftSettings = settings;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleClose();
          },
          child: Stack(
            children: [
              // Full-screen background semi-transparent
              Positioned.fill(
                child: Container(color: Colors.black.withAlpha(120)),
              ),
              Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: _width,
                    height: _height,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161616),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 60,
                                  offset: const Offset(0, 30),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(),
                                _buildTabBarSection(),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      Builder(builder: (_) => _buildGeneralTab(_draftSettings!)),
                                      Builder(builder: (_) => _buildViewersTab()),
                                      Builder(builder: (_) => _buildSecurityTab()),
                                      Builder(builder: (_) => _buildShortcutsTab()),
                                    ],
                                  ),
                                ),
                                _buildFooter(),
                              ],
                            ),
                          ),
                        ),

                        // Resize Handle
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeDownRight,
                            child: GestureDetector(
                              onPanStart: (_) =>
                                  setState(() => _isResizing = true),
                              onPanUpdate: (details) {
                                setState(() {
                                  _width = (_width + details.delta.dx).clamp(
                                    600,
                                    1200,
                                  );
                                  _height = (_height + details.delta.dy).clamp(
                                    400,
                                    900,
                                  );
                                });
                              },
                              onPanEnd: (_) {
                                setState(() => _isResizing = false);
                                ref
                                    .read(settingsProvider.notifier)
                                    .setSettingsDimensions(_width, _height);
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                padding: const EdgeInsets.all(4),
                                child: CustomPaint(
                                  painter: _ResizeHandlePainter(
                                    color: _isResizing
                                        ? Colors.white70
                                        : Colors.white24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.violet),
      ),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Future<void> _handleClose() async {
    if (_draftSettings != _originalSettings) {
      final discard = await showVibrantConfirmDialog(
        context: context,
        title: 'Discard Changes?',
        message:
            'You have unsaved changes. Are you sure you want to discard them?',
        confirmLabel: 'Discard',
        confirmColor: Colors.redAccent,
      );
      if (discard && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSave() async {
    if (_draftSettings != null) {
      final hwDecChanged =
          _draftSettings!.selectedHwDec != _originalSettings?.selectedHwDec;

      await ref.read(settingsProvider.notifier).saveSettings(_draftSettings!);

      if (mounted) {
        if (hwDecChanged) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Restart Required',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                'Hardware configuration changed. The application must be restarted for these changes to take effect.',
                style: GoogleFonts.manrope(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => exit(0),
                  child: Text(
                    'OK',
                    style: GoogleFonts.manrope(
                      color: AppColors.violet,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'SETTINGS',
            style: AppTheme.labelStyle.copyWith(
              letterSpacing: 2.0,
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: _buildTabBar(),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelPadding: const EdgeInsets.symmetric(horizontal: 20),
      dividerColor: Colors.transparent,
      indicator: GradientUnderlineTabIndicator(
        gradient: AppTheme.primaryGradient,
        width: 2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
        ),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: Colors.white.withOpacity(0.9),
      unselectedLabelColor: AppColors.textMuted.withOpacity(0.5),
      tabs: [
        _buildTab(0, 'General'),
        _buildTab(1, 'Viewers/Players'),
        _buildTab(2, 'Security'),
        _buildTab(3, 'Shortcuts'),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _tabController.index == index;
    final style = GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 0.5,
    );

    if (isSelected) {
      return Tab(
        child: ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(label, style: style.copyWith(color: Colors.white)),
        ),
      );
    }

    return Tab(
      child: Text(label, style: style.copyWith(color: AppColors.textMuted)),
    );
  }

  Widget _buildGeneralTab(AppSettings settings) {
    return Row(
      children: [
        _buildSubSidebar(
          items: ['Files & Folders', 'Download Manager', 'Sync', 'Performance'],
          activeItem: _activeGeneralSection,
          onSelected: (section) =>
              _scrollToSection(_generalKeys[section]!, section, 'General'),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _generalScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  'Files & Folders',
                  _generalKeys['Files & Folders']!,
                ),
                _buildSettingTile(
                  title: 'Show hidden files',
                  subtitle:
                      'Show hidden files like dot files in the file manager',
                  trailing: OnyxSwitch(
                    value: settings.showHiddenFiles,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          showHiddenFiles: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Max concurrent tasks',
                  subtitle:
                      'Maximum number of background file operations running simultaneously',
                  trailing: _buildDropdown<int>(
                    value:
                        (settings.maxConcurrentTasks < 1 ||
                            settings.maxConcurrentTasks > 3)
                        ? 3
                        : settings.maxConcurrentTasks,
                    options: List.generate(
                      3,
                      (i) => i + 1,
                    ).map((v) => MapEntry(v, '$v')).toList(),
                    minWidth: 60,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          maxConcurrentTasks: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Global default sort',
                  subtitle:
                      'The sort order used for folders without a specific preference',
                  trailing: _buildDropdown<SortOption>(
                    value: settings.globalSortOption,
                    options: SortOption.values
                        .map((v) => MapEntry(v, v.label))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          globalSortOption: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSectionHeader(
                  'Download Manager',
                  _generalKeys['Download Manager']!,
                ),
                _buildSettingTile(
                  title: 'Download to current folder',
                  subtitle:
                      'Save downloaded media to the currently viewed directory instead of the default Downloads folder',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.downloadToCurrentFolder ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          downloadToCurrentFolder: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Browser for Cookie Extraction',
                  subtitle:
                      'Used for age-restricted or private downloads (e.g. Instagram). Default is system browser.',
                  trailing: _buildDropdown<String>(
                    value:
                        settings.downloadBrowser ?? _defaultBrowser ?? 'None',
                    options: [
                      if (_defaultBrowser != null)
                        MapEntry(
                          _defaultBrowser!,
                          '$_defaultBrowser (Default)',
                        ),
                      ..._installedBrowsers
                          .where((b) => b != _defaultBrowser)
                          .map((b) => MapEntry(b, b)),
                      const MapEntry('None', 'None (Disabled)'),
                    ],
                    minWidth: 150,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          downloadBrowser: value == 'None' ? 'None' : value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Max concurrent downloads',
                  subtitle:
                      'Maximum number of media downloads running simultaneously',
                  trailing: _buildDropdown<int>(
                    value: settings.maxConcurrentDownloads.clamp(1, 10),
                    options: [
                      1,
                      2,
                      3,
                      5,
                      8,
                      10,
                    ].map((v) => MapEntry(v, '$v')).toList(),
                    minWidth: 60,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          maxConcurrentDownloads: value,
                        );
                      });
                    },
                  ),
                ),
                _buildInstalledEnginesSection(),
                _buildSectionHeader('Sync', _generalKeys['Sync']!),
                _buildEmptySection(
                  'Sync settings and cloud integration options will appear here.',
                ),
                _buildSectionHeader(
                  'Performance',
                  _generalKeys['Performance']!,
                ),
                _buildSettingTile(
                  title: 'Hardware Decoder',
                  subtitle:
                      'Choose the driver used for video decoding. Restart required.',
                  trailing: _buildDropdown<String>(
                    value: settings.selectedHwDec,
                    options: const [
                      MapEntry('auto', 'Auto (Recommended)'),
                      MapEntry('vaapi', 'VA-API (AMD / Intel)'),
                      MapEntry('nvdec', 'NVDEC (NVIDIA)'),
                      MapEntry('d3d11va', 'D3D11VA (Windows)'),
                      MapEntry('no', 'Software (CPU Fallback)'),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          selectedHwDec: value,
                          cachedResolvedHwDec: null,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(
                  height: 100,
                ), // Space to allow scrolling to final section
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewersTab() {
    return Row(
      children: [
        _buildSubSidebar(
          items: ['Image', 'Video', 'Audio', 'Documents'],
          activeItem: _activeViewersSection,
          onSelected: (section) => _scrollToSection(
            _viewersKeys[section]!,
            section,
            'Viewers/Players',
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _viewersScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Image', _viewersKeys['Image']!),
                _buildSettingTile(
                  title: 'Confirm delete',
                  subtitle:
                      'Show confirmation dialog before moving an image to Trash',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.confirmDeleteImage ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          confirmDeleteImage: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSectionHeader('Video', _viewersKeys['Video']!),
                _buildSettingTile(
                  title: 'Confirm delete',
                  subtitle:
                      'Show confirmation dialog before moving a video to Trash',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.confirmDeleteVideo ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          confirmDeleteVideo: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Auto play next',
                  subtitle:
                      'Automatically play the next video in the folder when the current one finishes',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.autoPlayNext ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          autoPlayNext: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Resume playback',
                  subtitle:
                      'Remember and resume from the last playback position for each video',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.resumePlayback ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          resumePlayback: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Seek time',
                  subtitle:
                      'The number of seconds to seek when using double-tap or arrow keys',
                  trailing: _buildDropdown<int>(
                    value: _draftSettings?.doubleTapSeekSeconds ?? 10,
                    options: [
                      5,
                      10,
                      15,
                      20,
                      25,
                      30,
                    ].map((v) => MapEntry(v, '${v}s')).toList(),
                    minWidth: 80,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          doubleTapSeekSeconds: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Vertical Scroll Speed Control',
                  subtitle:
                      'Use the left side of the screen to control playback speed via trackpad',
                  trailing: _buildDropdown<SpeedControlOption>(
                    value:
                        _draftSettings?.trackpadSpeedControl ??
                        SpeedControlOption.off,
                    options: SpeedControlOption.values
                        .map((v) => MapEntry(v, v.label))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          trackpadSpeedControl: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Show markers on timeline',
                  subtitle: 'Render saved markers above the video progress bar',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.showMarkersOnTimeline ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          showMarkersOnTimeline: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSectionHeader('Audio', _viewersKeys['Audio']!),
                _buildSettingTile(
                  title: 'Show hidden files',
                  subtitle:
                      'Show hidden files and folders starting with a dot in the audio player',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.showHiddenAudioFiles ?? false,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          showHiddenAudioFiles: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Auto play next',
                  subtitle:
                      'Automatically play the next audio file in the folder when the current one finishes',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.audioAutoPlayNext ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          audioAutoPlayNext: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Seek duration',
                  subtitle:
                      'Seconds to seek when using arrow keys in the audio player',
                  trailing: _buildDropdown<int>(
                    value: _draftSettings?.audioSeekSeconds ?? 5,
                    options: [
                      3,
                      5,
                      10,
                      15,
                      30,
                    ].map((v) => MapEntry(v, '${v}s')).toList(),
                    minWidth: 80,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          audioSeekSeconds: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Confirm delete',
                  subtitle:
                      'Show confirmation dialog before moving an audio to Trash',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.confirmDeleteAudio ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          confirmDeleteAudio: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSectionHeader('Documents', _viewersKeys['Documents']!),
                _buildSettingTile(
                  title: 'Confirm delete',
                  subtitle:
                      'Show confirmation dialog before moving a document to Trash',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.confirmDeleteDocument ?? true,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          confirmDeleteDocument: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Case sensitive search',
                  subtitle:
                      'Match exact casing when searching within documents',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.documentSearchCaseSensitive ?? false,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          documentSearchCaseSensitive: value,
                        );
                      });
                    },
                  ),
                ),
                _buildSettingTile(
                  title: 'Use regular expressions',
                  subtitle:
                      'Treat document search queries as regular expressions by default',
                  trailing: OnyxSwitch(
                    value: _draftSettings?.documentSearchUseRegex ?? false,
                    onChanged: (value) {
                      setState(() {
                        _draftSettings = _draftSettings!.copyWith(
                          documentSearchUseRegex: value,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return Row(
      children: [
        _buildSubSidebar(
          items: ['Vault', 'Encryption'],
          activeItem: _activeSecuritySection,
          onSelected: (section) =>
              _scrollToSection(_securityKeys[section]!, section, 'Security'),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _securityScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Vault', _securityKeys['Vault']!),
                _buildEmptySection('Secure vault storage and access control.'),
                _buildSectionHeader('Encryption', _securityKeys['Encryption']!),
                _buildEmptySection(
                  'End-to-end encryption for file operations.',
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutsTab() {
    return Row(
      children: [
        _buildSubSidebar(
          items: [
            'General',
            'Download Manager',
            'Image Viewer',
            'Video Player',
            'Audio Player',
            'Document Viewer',
          ],
          activeItem: _activeShortcutsSection,
          onSelected: (section) =>
              _scrollToSection(_shortcutsKeys[section]!, section, 'Shortcuts'),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _shortcutsScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('General', _shortcutsKeys['General']!),
                _buildShortcutTile('Select All', ['Ctrl', 'A']),
                _buildShortcutTile('Copy', ['Ctrl', 'C']),
                _buildShortcutTile('Cut', ['Ctrl', 'X']),
                _buildShortcutTile('Paste', ['Ctrl', 'V']),
                _buildShortcutTile('Move to Trash', ['Del']),
                _buildShortcutTile('Delete Permanently', ['Shift', 'Del']),
                _buildShortcutTile('Rename', ['F2']),
                _buildShortcutTile('New Folder', ['Ctrl', 'Shift', 'N']),
                _buildShortcutTile('Compress', ['Ctrl', 'Alt', 'C']),
                _buildShortcutTile('Zoom In', ['Ctrl', '+']),
                _buildShortcutTile('Zoom Out', ['Ctrl', '-']),
                _buildShortcutTile('Reset Zoom', ['Ctrl', '0']),
                _buildShortcutTile('Toggle Search', ['Ctrl', 'F']),
                _buildShortcutTile('Refresh', ['Ctrl', 'R', 'or', 'F5']),
                _buildShortcutTile('Toggle Hidden Files', ['Ctrl', '.']),
                _buildShortcutTile('Toggle Sidebar', ['Ctrl', 'B']),
                _buildShortcutTile('Focus Path Input', ['Alt', 'D']),
                _buildShortcutTile('Add New Tab', ['Ctrl', 'T']),
                _buildShortcutTile('Close Active Tab', ['Ctrl', 'W']),
                _buildShortcutTile('Switch to Next Tab', ['Ctrl', 'Tab']),
                _buildShortcutTile('Switch to Previous Tab', [
                  'Ctrl',
                  'Shift',
                  'Tab',
                ]),
                _buildShortcutTile('Open Selected Item', ['Enter']),
                _buildShortcutTile('Show Properties', ['Alt', 'Enter']),
                _buildShortcutTile('Go Back', [
                  'Backspace',
                  'or',
                  'Alt',
                  'Left',
                ]),
                _buildShortcutTile('Go Forward', ['Alt', 'Right']),
                _buildShortcutTile('Clear Selection', ['Esc']),

                _buildSectionHeader(
                  'Download Manager',
                  _shortcutsKeys['Download Manager']!,
                ),
                _buildShortcutTile('Update List (Save)', ['Ctrl', 'S']),
                _buildShortcutTile('Select All Items', ['Ctrl', 'A']),
                _buildShortcutTile('Remove Selected Items', ['Del']),
                _buildShortcutTile('Next Item', ['Down']),
                _buildShortcutTile('Select Next Item', ['Shift', 'Down']),
                _buildShortcutTile('Previous Item', ['Up']),
                _buildShortcutTile('Select Previous Item', ['Shift', 'Up']),
                _buildShortcutTile('Cancel / Dismiss Dialog', ['Esc']),

                _buildSectionHeader(
                  'Image Viewer',
                  _shortcutsKeys['Image Viewer']!,
                ),
                _buildShortcutTile('Toggle Fullscreen', ['F']),
                _buildShortcutTile('Next Image', ['Right']),
                _buildShortcutTile('Previous Image', ['Left']),
                _buildShortcutTile('Zoom In', ['Ctrl', '+']),
                _buildShortcutTile('Zoom Out', ['Ctrl', '-']),
                _buildShortcutTile('Reset Zoom', ['Ctrl', '0']),
                _buildShortcutTile('Move to Trash', ['Del']),
                _buildShortcutTile('Go Back / Close', [
                  'Backspace',
                  'or',
                  'Alt',
                  'Left',
                ]),
                _buildShortcutTile('Close Viewer', ['Ctrl', 'W']),

                _buildSectionHeader(
                  'Video Player',
                  _shortcutsKeys['Video Player']!,
                ),
                _buildShortcutTile('Play / Pause', ['Space']),
                _buildShortcutTile('Seek Backward', ['Left']),
                _buildShortcutTile('Seek Forward', ['Right']),
                _buildShortcutTile('Volume Up', ['Up']),
                _buildShortcutTile('Volume Down', ['Down']),
                _buildShortcutTile('Mute / Unmute', ['M']),
                _buildShortcutTile('Toggle Fullscreen', ['F']),
                _buildShortcutTile('Take Snapshot', ['S']),
                _buildShortcutTile('Toggle Marker Editor', ['T']),
                _buildShortcutTile('Save Marker', ['Enter']),
                _buildShortcutTile('Move to Trash', ['Del']),
                _buildShortcutTile('Go Back', [
                  'Backspace',
                  'or',
                  'Alt',
                  'Left',
                ]),
                _buildShortcutTile('Close Player', ['Ctrl', 'W']),

                _buildSectionHeader(
                  'Audio Player',
                  _shortcutsKeys['Audio Player']!,
                ),
                _buildShortcutTile('Play / Pause', ['Space']),
                _buildShortcutTile('Seek Backward', ['Left']),
                _buildShortcutTile('Seek Forward', ['Right']),
                _buildShortcutTile('Volume Up', ['Up']),
                _buildShortcutTile('Volume Down', ['Down']),
                _buildShortcutTile('Mute / Unmute', ['M']),
                _buildShortcutTile('Reveal in File Manager', ['Ctrl', 'R']),
                _buildShortcutTile('Rename', ['F2']),
                _buildShortcutTile('Move to Trash', ['Del']),
                _buildShortcutTile('Show Properties', ['Alt', 'Enter']),
                _buildShortcutTile('Close Dialogs', ['Esc']),

                _buildSectionHeader(
                  'Document Viewer',
                  _shortcutsKeys['Document Viewer']!,
                ),
                _buildShortcutTile('Next Document', ['Right']),
                _buildShortcutTile('Previous Document', ['Left']),
                _buildShortcutTile('Move to Trash', ['Del']),
                _buildShortcutTile('Go Back', [
                  'Backspace',
                  'or',
                  'Alt',
                  'Left',
                ]),
                _buildShortcutTile('Close Viewer', ['Ctrl', 'W']),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutTile(String description, List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            description,
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: keys.map((keyStr) {
              if (keyStr.toLowerCase() == 'or') {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'or',
                    style: GoogleFonts.manrope(
                      color: AppColors.textMuted.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  keyStr,
                  style: GoogleFonts.firaCode(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubSidebar({
    required List<String> items,
    required String activeItem,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      width: 180,
      color: Colors.black.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = activeItem == item;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: () => onSelected(item),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withAlpha(20)
                        : Colors.transparent,
                  ),
                ),
                child: Tooltip(
                  message: item,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : AppColors.textMuted.withOpacity(0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, GlobalKey key) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.violet.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 13,
          color: AppColors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textMuted.withOpacity(0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<MapEntry<T, String>> options,
    required ValueChanged<T> onChanged,
    double minWidth = 100,
  }) {
    final selectedOption = options.firstWhere((o) => o.key == value);

    return PopupMenuButton<T>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF161616),
      elevation: 24,
      onSelected: onChanged,
      tooltip: '',
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: minWidth),
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt.key == value;
        return PopupMenuItem<T>(
          value: opt.key,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              opt.value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedOption.value,
              style: GoogleFonts.manrope(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstalledEnginesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INSTALLED ENGINES',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.violet.withOpacity(0.8),
                ),
              ),
              if (ref.watch(downloaderUpdateProvider).isUpdating)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.violet.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.violet,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Updating...',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.violet,
                        ),
                      ),
                    ],
                  ),
                )
              else if (ref.watch(downloaderUpdateProvider).isCheckingForUpdates)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.violet.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.violet,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checking...',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.violet,
                        ),
                      ),
                    ],
                  ),
                )
              else
                (() {
                  final updateState = ref.watch(downloaderUpdateProvider);
                  final hasUpdates = EngineRegistry.allEngines.any((e) {
                    final vInst = updateState.installedVersions[e.id];
                    final vLat = updateState.latestVersions[e.id];
                    return e.isInstalled &&
                        vInst != null &&
                        vLat != null &&
                        vInst != vLat;
                  });

                  if (hasUpdates) {
                    return GestureDetector(
                      onTap: () {
                        ref.read(downloaderUpdateProvider.notifier).updateAll();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.violet,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.system_update_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Update All',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildEngineActionButton(
                    label: 'Check for Updates',
                    icon: Icons.sync_rounded,
                    color: AppColors.violet,
                    onTap: () {
                      ref
                          .read(downloaderUpdateProvider.notifier)
                          .checkForUpdates();
                    },
                  );
                })(),
            ],
          ),
        ),
        // Engine list
        ...EngineRegistry.allEngines.map((engine) {
          final installed = engine.isInstalled;
          final updateState = ref.watch(downloaderUpdateProvider);
          final progress = updateState.engineProgress[engine.id];
          final isUpdating =
              progress != null ||
              (updateState.isUpdating && engine.updateInfo != null);

          double displayProgress = progress ?? 0.0;
          if (updateState.isUpdating &&
              engine.updateInfo != null &&
              progress == null) {
            displayProgress =
                -1.0; // Show indeterminate if global update is running
          }

          final vInst = updateState.installedVersions[engine.id];
          final vLat = updateState.latestVersions[engine.id];
          final hasUpdate = vInst != null && vLat != null && vInst != vLat;
          final errorString = updateState.error;
          final engineError =
              (errorString != null && errorString.startsWith('${engine.id}:'))
              ? errorString.substring(engine.id.length + 1)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: engineError != null
                        ? Colors.redAccent.withOpacity(0.3)
                        : (installed
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.03)),
                  ),
                ),
                child: Stack(
                  children: [
                    // Progress Background
                    if (isUpdating && displayProgress >= 0.0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(
                              begin: 0,
                              end: displayProgress.clamp(0.0, 1.0),
                            ),
                            builder: (context, value, child) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value,
                                child: Container(
                                  color: Colors.green.withOpacity(0.15),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else if (isUpdating && displayProgress < 0.0)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: Colors.green.withOpacity(0.15),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Engine icon
                          Icon(
                            engine.icon,
                            size: 18,
                            color: installed
                                ? engine.color
                                : engine.color.withOpacity(0.3),
                          ),
                          const SizedBox(width: 10),
                          // Engine name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  installed && vInst != null
                                      ? '${engine.displayName} (v$vInst)'
                                      : engine.displayName,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: installed
                                        ? Colors.white.withOpacity(0.85)
                                        : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                if (engine.isOptional)
                                  Text(
                                    'Optional',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      color: AppColors.textMuted.withOpacity(
                                        0.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Status badge
                          if (!installed || engineError != null || isUpdating)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: engineError != null
                                    ? Colors.redAccent.withOpacity(0.12)
                                    : isUpdating
                                    ? Colors.blue.withOpacity(0.12)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                engineError != null
                                    ? 'Error'
                                    : isUpdating
                                    ? (vInst != null
                                          ? 'Updating...'
                                          : 'Installing...')
                                    : 'Not Installed',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: engineError != null
                                      ? Colors.redAccent
                                      : isUpdating
                                      ? Colors.blue.shade300
                                      : AppColors.textMuted.withOpacity(0.4),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Action buttons
                          if (!isUpdating) ...[
                            if (engineError != null)
                              _buildEngineActionButton(
                                label: 'Error',
                                icon: Icons.error_outline_rounded,
                                color: Colors.redAccent,
                                onTap: () {},
                              )
                            else if (installed) ...[
                              if (hasUpdate)
                                _buildEngineActionButton(
                                  label: 'Update',
                                  icon: Icons.refresh_rounded,
                                  color: AppColors.violet,
                                  onTap: () {
                                    ref
                                        .read(downloaderUpdateProvider.notifier)
                                        .updateEngine(engine);
                                  },
                                )
                              else if (vInst != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Up to date',
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                              // Delete button
                              if (engine.isOptional)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _buildEngineActionButton(
                                    label: switch (engine.id) {
                                      'playwright' => 'Uninstall (~300 MB)',
                                      'streamlink' => 'Uninstall (~25 MB)',
                                      'lux' => 'Uninstall (~15 MB)',
                                      'you-get' => 'Uninstall (~10 MB)',
                                      _ => 'Uninstall',
                                    },
                                    icon: Icons.delete_outline_rounded,
                                    color: Colors.redAccent.shade100,
                                    onTap: () async {
                                      final confirm = await showVibrantConfirmDialog(
                                        context: context,
                                        title:
                                            'Uninstall ${engine.displayName}?',
                                        message: engine.id == 'playwright'
                                            ? 'This will remove Playwright and Chromium browser (~300 MB). You can reinstall it later.'
                                            : 'This will uninstall ${engine.displayName}. You can reinstall it later.',
                                        confirmLabel: 'Uninstall',
                                        confirmColor: Colors.redAccent,
                                      );
                                      if (confirm && mounted) {
                                        final processFuture = engine
                                            .uninstall();
                                        if (processFuture != null) {
                                          ref
                                              .read(
                                                downloaderUpdateProvider
                                                    .notifier,
                                              )
                                              .installProcessEngine(
                                                engine,
                                                processFuture,
                                              );
                                        }
                                      }
                                    },
                                  ),
                                ),
                            ] else ...[
                              // Install button
                              _buildEngineActionButton(
                                label: engine.updateInfo != null
                                    ? 'Download'
                                    : 'Install',
                                icon: Icons.download_rounded,
                                color: AppColors.violet,
                                onTap: () {
                                  if (engine.updateInfo != null) {
                                    ref
                                        .read(downloaderUpdateProvider.notifier)
                                        .updateEngine(engine);
                                  } else if (engine.install != null) {
                                    final processFuture = engine.install();
                                    if (processFuture != null) {
                                      ref
                                          .read(
                                            downloaderUpdateProvider.notifier,
                                          )
                                          .installProcessEngine(
                                            engine,
                                            processFuture,
                                          );
                                    }
                                  }
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (engineError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Installation Error',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            engineError,
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
        // aria2 accelerator
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.speed_rounded,
                size: 18,
                color: Aria2Accelerator.isAvailable
                    ? Colors.cyanAccent
                    : Colors.cyanAccent.withOpacity(0.3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'aria2 — Download Accelerator',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Aria2Accelerator.isAvailable
                            ? Colors.white.withOpacity(0.85)
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                    if (!Aria2Accelerator.isAvailable)
                      Text(
                        'Install via: sudo apt install aria2',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          color: AppColors.textMuted.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Aria2Accelerator.isAvailable
                      ? Colors.green.withOpacity(0.12)
                      : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  Aria2Accelerator.isAvailable ? 'Active' : 'Not Found',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Aria2Accelerator.isAvailable
                        ? Colors.green.shade300
                        : AppColors.textMuted.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngineActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: _handleSave,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientUnderlineTabIndicator extends Decoration {
  const GradientUnderlineTabIndicator({
    required this.gradient,
    this.width = 3.0,
    this.borderRadius,
  });

  final Gradient gradient;
  final double width;
  final BorderRadiusGeometry? borderRadius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientUnderlinePainter(this, onChanged);
  }
}

class _GradientUnderlinePainter extends BoxPainter {
  _GradientUnderlinePainter(this.decoration, VoidCallback? onChanged)
    : super(onChanged);

  final GradientUnderlineTabIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & (configuration.size ?? Size.zero);
    final paint = Paint()
      ..shader = decoration.gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final indicatorRect = Rect.fromLTWH(
      rect.left,
      rect.bottom - decoration.width,
      rect.width,
      decoration.width,
    );

    if (decoration.borderRadius != null) {
      canvas.drawRRect(
        decoration.borderRadius!
            .resolve(configuration.textDirection)
            .toRRect(indicatorRect),
        paint,
      );
    } else {
      canvas.drawRect(indicatorRect, paint);
    }
  }
}

class _ResizeHandlePainter extends CustomPainter {
  final Color color;
  _ResizeHandlePainter({this.color = Colors.white24});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw three diagonal lines for the handle
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.7),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.4, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
