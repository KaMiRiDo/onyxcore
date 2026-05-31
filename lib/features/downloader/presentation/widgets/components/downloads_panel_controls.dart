part of '../downloads_panel.dart';

extension DownloadsPanelControls on _MediaDownloaderPanelState {
  Widget _buildEngineDropdown() {
    final options = [
      {
        'key': 'auto',
        'label': 'Auto Select',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.violet,
      },
      {
        'key': 'yt-dlp',
        'label': 'yt-dlp',
        'icon': Icons.video_library_rounded,
        'color': Colors.redAccent,
      },
      {
        'key': 'gallery-dl',
        'label': 'gallery-dl',
        'icon': Icons.photo_library_rounded,
        'color': Colors.blueAccent,
      },
    ];

    final selected = options.firstWhere((o) => o['key'] == _selectedEngine);

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (val) {
        setState(() => _selectedEngine = val);
      },
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt['key'] == _selectedEngine;
        return PopupMenuItem<String>(
          value: opt['key'] as String,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt['icon'] as IconData,
                  size: 16,
                  color: opt['color'] as Color,
                ),
                const SizedBox(width: 8),
                Text(
                  opt['label'] as String,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected['icon'] as IconData,
              size: 16,
              color: selected['color'] as Color,
            ),
            const SizedBox(width: 8),
            Text(
              selected['label'] as String,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupFilterDropdown(DownloadConfig config, MediaGroup group) {
    bool hasImages = group.items.any((item) => !item.isVideo);
    bool hasVideos = group.items.any((item) => item.isVideo);
    bool isEnabled = group.first.isProfile || (hasImages && hasVideos);

    String getLabel(GroupDownloadType type) {
      switch (type) {
        case GroupDownloadType.all:
          return 'All';
        case GroupDownloadType.images:
          return 'Images Only';
        case GroupDownloadType.videos:
          return 'Videos Only';
      }
    }

    return PopupMenuButton<GroupDownloadType>(
      enabled: isEnabled,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxHeight: 250),
      onSelected: (val) {
        setState(() {
          config.groupFilter = val;
          _previewCarouselIndex = 0;
        });
      },
      itemBuilder: (context) => GroupDownloadType.values.map((f) {
        final isSelected = f == config.groupFilter;
        return PopupMenuItem<GroupDownloadType>(
          value: f,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withAlpha(15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              getLabel(f),
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isEnabled ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(isEnabled ? 0.1 : 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                getLabel(config.groupFilter),
                style: GoogleFonts.manrope(
                  color: isEnabled ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isEnabled)
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    final options = [
      {
        'key': 'current',
        'label': 'Current Location',
        'icon': Icons.folder_open_rounded,
      },
      {
        'key': 'system',
        'label': 'Downloads Folder',
        'icon': Icons.download_done_rounded,
      },
    ];

    final selected = options.firstWhere((o) => o['key'] == _destinationMode);

    return PopupMenuButton<String>(
      offset: const Offset(0, -90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (val) {
        setState(() => _destinationMode = val);
      },
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt['key'] == _destinationMode;
        return PopupMenuItem<String>(
          value: opt['key'] as String,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt['icon'] as IconData,
                  size: 16,
                  color: isSelected ? AppColors.violet : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  opt['label'] as String,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected['icon'] as IconData, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected['label'] as String,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
