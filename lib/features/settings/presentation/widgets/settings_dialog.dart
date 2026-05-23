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


class SettingsDialog extends ConsumerStatefulWidget {
  final int initialTab;
  final String? initialSection;

  const SettingsDialog({
    this.initialTab = 0,
    this.initialSection,
    super.key,
  });

  static Future<void> show(BuildContext context, {int initialTab = 0, String? section}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) => SettingsDialog(initialTab: initialTab, initialSection: section),
    );
  }

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Scroll controllers for each tab
  final _generalScrollController = ScrollController();
  final _viewersScrollController = ScrollController();
  final _securityScrollController = ScrollController();

  // Keys for sections to enable auto-scrolling
  final _generalKeys = {
    'Files & Folders': GlobalKey(),
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

  String _activeGeneralSection = 'Files & Folders';
  String _activeViewersSection = 'Image';
  String _activeSecuritySection = 'Vault';

  late double _width;
  late double _height;
  bool _isResizing = false;

  // Draft state for buffered saving
  AppSettings? _draftSettings;
  AppSettings? _originalSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tabName = widget.initialTab == 0 
            ? 'General' 
            : (widget.initialTab == 1 ? 'Viewers/Players' : 'Security');
        
        GlobalKey? targetKey;
        if (tabName == 'General') targetKey = _generalKeys[widget.initialSection];
        if (tabName == 'Viewers/Players') targetKey = _viewersKeys[widget.initialSection];
        if (tabName == 'Security') targetKey = _securityKeys[widget.initialSection];

        if (targetKey != null) {
          _scrollToSection(targetKey, widget.initialSection!, tabName);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _generalScrollController.dispose();
    _viewersScrollController.dispose();
    _securityScrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key, String sectionName, String tab) {
    setState(() {
      if (tab == 'General') _activeGeneralSection = sectionName;
      if (tab == 'Viewers/Players') _activeViewersSection = sectionName;
      if (tab == 'Security') _activeSecuritySection = sectionName;
    });

    final context = key.currentContext;
    if (context != null) {
      final scrollController = tab == 'General'
          ? _generalScrollController
          : tab == 'Viewers/Players'
              ? _viewersScrollController
              : _securityScrollController;

      final RenderBox box = context.findRenderObject() as RenderBox;
      final RenderBox? viewport = scrollController.position.context.storageContext.findRenderObject() as RenderBox?;
      
      if (viewport != null) {
        final offset = box.localToGlobal(Offset.zero, ancestor: viewport);
        scrollController.animateTo(
          (scrollController.offset + offset.dy).clamp(0.0, scrollController.position.maxScrollExtent),
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
              // Full-screen background blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withAlpha(50)),
                ),
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
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161616).withOpacity(0.98),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                                        _buildGeneralTab(_draftSettings!),
                                        _buildViewersTab(),
                                        _buildSecurityTab(),
                                      ],
                                    ),
                                  ),
                                  _buildFooter(),
                                ],
                              ),
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
                              onPanStart: (_) => setState(() => _isResizing = true),
                              onPanUpdate: (details) {
                                setState(() {
                                  _width = (_width + details.delta.dx).clamp(600, 1200);
                                  _height = (_height + details.delta.dy).clamp(400, 900);
                                });
                              },
                              onPanEnd: (_) {
                                setState(() => _isResizing = false);
                                ref.read(settingsProvider.notifier).setSettingsDimensions(_width, _height);
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                padding: const EdgeInsets.all(4),
                                child: CustomPaint(painter: _ResizeHandlePainter(color: _isResizing ? Colors.white70 : Colors.white24)),
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
        message: 'You have unsaved changes. Are you sure you want to discard them?',
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
      final hwDecChanged = _draftSettings!.selectedHwDec != _originalSettings?.selectedHwDec;
      
      await ref.read(settingsProvider.notifier).saveSettings(_draftSettings!);
      
      if (mounted) {
        if (hwDecChanged) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
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
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
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
          items: ['Files & Folders', 'Sync', 'Performance'],
          activeItem: _activeGeneralSection,
          onSelected: (section) => _scrollToSection(_generalKeys[section]!, section, 'General'),
        ),
        Expanded(
          child: ListView(
            controller: _generalScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildSectionHeader('Files & Folders', _generalKeys['Files & Folders']!),
              _buildSettingTile(
                title: 'Show hidden files',
                subtitle: 'Show hidden files like dot files in the file manager',
                trailing: OnyxSwitch(
                  value: settings.showHiddenFiles,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(showHiddenFiles: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Max concurrent tasks',
                subtitle: 'Maximum number of background file operations running simultaneously',
                trailing: _buildDropdown<int>(
                  value: (settings.maxConcurrentTasks < 1 || settings.maxConcurrentTasks > 3) 
                      ? 3 
                      : settings.maxConcurrentTasks,
                  options: List.generate(3, (i) => i + 1)
                      .map((v) => MapEntry(v, '$v'))
                      .toList(),
                  minWidth: 60,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(maxConcurrentTasks: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Global default sort',
                subtitle: 'The sort order used for folders without a specific preference',
                trailing: _buildDropdown<SortOption>(
                  value: settings.globalSortOption,
                  options: SortOption.values
                      .map((v) => MapEntry(v, v.label))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(globalSortOption: value);
                    });
                  },
                ),
              ),
              _buildSectionHeader('Sync', _generalKeys['Sync']!),
              _buildEmptySection('Sync settings and cloud integration options will appear here.'),
              _buildSectionHeader('Performance', _generalKeys['Performance']!),
              _buildSettingTile(
                title: 'Hardware Decoder',
                subtitle: 'Choose the driver used for video decoding. Restart required.',
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
              const SizedBox(height: 100), // Space to allow scrolling to final section
            ],
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
          onSelected: (section) => _scrollToSection(_viewersKeys[section]!, section, 'Viewers/Players'),
        ),
        Expanded(
          child: ListView(
            controller: _viewersScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildSectionHeader('Image', _viewersKeys['Image']!),
              _buildSettingTile(
                title: 'Confirm delete',
                subtitle: 'Show confirmation dialog before moving an image to Trash',
                trailing: OnyxSwitch(
                  value: _draftSettings?.confirmDeleteImage ?? true,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(confirmDeleteImage: value);
                    });
                  },
                ),
              ),
              _buildSectionHeader('Video', _viewersKeys['Video']!),
              _buildSettingTile(
                title: 'Confirm delete',
                subtitle: 'Show confirmation dialog before moving a video to Trash',
                trailing: OnyxSwitch(
                  value: _draftSettings?.confirmDeleteVideo ?? true,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(confirmDeleteVideo: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Auto play next',
                subtitle: 'Automatically play the next video in the folder when the current one finishes',
                trailing: OnyxSwitch(
                  value: _draftSettings?.autoPlayNext ?? true,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(autoPlayNext: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Resume playback',
                subtitle: 'Remember and resume from the last playback position for each video',
                trailing: OnyxSwitch(
                  value: _draftSettings?.resumePlayback ?? true,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(resumePlayback: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Seek time',
                subtitle: 'The number of seconds to seek when using double-tap or arrow keys',
                trailing: _buildDropdown<int>(
                  value: _draftSettings?.doubleTapSeekSeconds ?? 10,
                  options: [5, 10, 15, 20, 25, 30]
                      .map((v) => MapEntry(v, '${v}s'))
                      .toList(),
                  minWidth: 80,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(doubleTapSeekSeconds: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Vertical Scroll Speed Control',
                subtitle: 'Use the left side of the screen to control playback speed via trackpad',
                trailing: _buildDropdown<SpeedControlOption>(
                  value: _draftSettings?.trackpadSpeedControl ?? SpeedControlOption.off,
                  options: SpeedControlOption.values
                      .map((v) => MapEntry(v, v.label))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(trackpadSpeedControl: value);
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
                      _draftSettings = _draftSettings!.copyWith(showMarkersOnTimeline: value);
                    });
                  },
                ),
              ),
              _buildSectionHeader('Audio', _viewersKeys['Audio']!),
              _buildSettingTile(
                title: 'Show hidden files',
                subtitle: 'Show hidden files and folders starting with a dot in the audio player',
                trailing: OnyxSwitch(
                  value: _draftSettings?.showHiddenAudioFiles ?? false,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(showHiddenAudioFiles: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Seek duration',
                subtitle: 'Seconds to seek when using arrow keys in the audio player',
                trailing: _buildDropdown<int>(
                  value: _draftSettings?.audioSeekSeconds ?? 5,
                  options: [3, 5, 10, 15, 30]
                      .map((v) => MapEntry(v, '${v}s'))
                      .toList(),
                  minWidth: 80,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(audioSeekSeconds: value);
                    });
                  },
                ),
              ),
              _buildSettingTile(
                title: 'Confirm delete',
                subtitle: 'Show confirmation dialog before moving an audio to Trash',
                trailing: OnyxSwitch(
                  value: _draftSettings?.confirmDeleteAudio ?? true,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(confirmDeleteAudio: value);
                    });
                  },
                ),
              ),
              _buildSectionHeader('Documents', _viewersKeys['Documents']!),
              _buildSettingTile(
                title: 'Confirm delete',
                subtitle: 'Show confirmation dialog before moving a document to Trash',
                trailing: OnyxSwitch(
                  value: _draftSettings?.confirmDeleteDocument ?? true,
                  onChanged: (value) {
                    setState(() {
                      _draftSettings = _draftSettings!.copyWith(confirmDeleteDocument: value);
                    });
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
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
          onSelected: (section) => _scrollToSection(_securityKeys[section]!, section, 'Security'),
        ),
        Expanded(
          child: ListView(
            controller: _securityScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildSectionHeader('Vault', _securityKeys['Vault']!),
              _buildEmptySection('Secure vault storage and access control.'),
              _buildSectionHeader('Encryption', _securityKeys['Encryption']!),
              _buildEmptySection('End-to-end encryption for file operations.'),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withAlpha(15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white.withAlpha(20) : Colors.transparent,
                  ),
                ),
                child: Text(
                  item,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white.withOpacity(0.9) : AppColors.textMuted.withOpacity(0.6),
                    letterSpacing: 0.3,
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
              color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              opt.value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
    canvas.drawLine(Offset(size.width * 0.7, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.7), paint);
    canvas.drawLine(Offset(size.width * 0.4, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.4), paint);
    canvas.drawLine(Offset(size.width * 0.1, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

