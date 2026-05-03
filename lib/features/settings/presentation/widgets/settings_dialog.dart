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


class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) => const SettingsDialog(),
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
  };
  final _viewersKeys = {
    'Image': GlobalKey(),
    'Video': GlobalKey(),
    'Documents': GlobalKey(),
  };
  final _securityKeys = {
    'Vault': GlobalKey(),
    'Encryption': GlobalKey(),
  };

  String _activeGeneralSection = 'Files & Folders';
  String _activeViewersSection = 'Image';
  String _activeSecuritySection = 'Vault';

  // Draft state for buffered saving
  AppSettings? _draftSettings;
  AppSettings? _originalSettings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
      if (tab == 'Viewers') _activeViewersSection = sectionName;
      if (tab == 'Security') _activeSecuritySection = sectionName;
    });

    final context = key.currentContext;
    if (context != null) {
      final scrollController = tab == 'General'
          ? _generalScrollController
          : tab == 'Viewers'
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
                  child: Container(
                    width: 760,
                    height: 560,
                    margin: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F).withAlpha(235),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(160),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 20),
                            _buildTabBar(),
                            const SizedBox(height: 8),
                            Divider(color: Colors.white.withAlpha(20)),
                            const SizedBox(height: 24),
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
                            const SizedBox(height: 16),
                            _buildFooter(),
                          ],
                        ),
                      ),
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
      await ref.read(settingsProvider.notifier).saveSettings(_draftSettings!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Settings',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        IconButton(
          onPressed: _handleClose,
          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(10), width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.only(left: 0, right: 32),
        dividerColor: Colors.transparent, // We use the container border instead
        indicator: GradientUnderlineTabIndicator(
          gradient: AppTheme.primaryGradient,
          width: 3,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(3),
          ),
        ),

        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        tabs: [
          _buildTab(0, 'General'),
          _buildTab(1, 'Viewers'),
          _buildTab(2, 'Security'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _tabController.index == index;
    final style = GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
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
          items: ['Files & Folders', 'Sync'],
          activeItem: _activeGeneralSection,
          onSelected: (section) => _scrollToSection(_generalKeys[section]!, section, 'General'),
        ),
        const VerticalDivider(width: 1, color: Colors.white10),
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
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: DropdownButton<int>(
                    value: (settings.maxConcurrentTasks < 1 || settings.maxConcurrentTasks > 3) 
                        ? 3 
                        : settings.maxConcurrentTasks,
                    dropdownColor: const Color(0xFF1A1A1A),
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    items: List.generate(3, (i) => i + 1)
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _draftSettings = _draftSettings!.copyWith(maxConcurrentTasks: value);
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              _buildSectionHeader('Sync', _generalKeys['Sync']!),
              _buildEmptySection('Sync settings and cloud integration options will appear here.'),
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
          items: ['Image', 'Video', 'Documents'],
          activeItem: _activeViewersSection,
          onSelected: (section) => _scrollToSection(_viewersKeys[section]!, section, 'Viewers'),
        ),
        const VerticalDivider(width: 1, color: Colors.white10),
        Expanded(
          child: ListView(
            controller: _viewersScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildSectionHeader('Image', _viewersKeys['Image']!),
              _buildEmptySection('Image viewer configuration options.'),
              const SizedBox(height: 40),
              _buildSectionHeader('Video', _viewersKeys['Video']!),
              _buildEmptySection('Video playback and hardware acceleration.'),
              const SizedBox(height: 40),
              _buildSectionHeader('Documents', _viewersKeys['Documents']!),
              _buildEmptySection('PDF and text document viewing settings.'),
              const SizedBox(height: 100),
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
        const VerticalDivider(width: 1, color: Colors.white10),
        Expanded(
          child: ListView(
            controller: _securityScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _buildSectionHeader('Vault', _securityKeys['Vault']!),
              _buildEmptySection('Secure vault storage and access control.'),
              const SizedBox(height: 40),
              _buildSectionHeader('Encryption', _securityKeys['Encryption']!),
              _buildEmptySection('End-to-end encryption for file operations.'),
              const SizedBox(height: 100),
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
      width: 170, // Reduced for a more compact and elegant look
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
                    color: isSelected ? Colors.white : AppColors.textMuted,
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
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppColors.violet,
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
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textMuted,
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

  Widget _buildFooter() {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: _handleSave,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(26)),
          ),
          child: Text(
            'Save',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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

