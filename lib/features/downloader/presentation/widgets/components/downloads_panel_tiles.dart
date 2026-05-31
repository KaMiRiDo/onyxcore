part of '../downloads_panel.dart';

extension DownloadsPanelTiles on _MediaDownloaderPanelState {
  Widget _buildGroupTile(int index, MediaGroup group) {
    final item = group.first;
    final config = _configs[index]!;
    final isPlaylist = item.isPlaylist;

    return GestureDetector(
      onTap: () {
        _listFocusNode.requestFocus();
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        setState(() {
          if (isCtrl) {
            if (_selectedIndices.contains(index)) {
              _selectedIndices.remove(index);
              if (_anchorIndex == index) _anchorIndex = -1;
            } else {
              _selectedIndices.add(index);
              _anchorIndex = index;
            }
            _lastSelectedIndex = index;
          } else if (isShift && _anchorIndex != -1) {
            _lastSelectedIndex = index;
            _updateShiftSelection(_filteredItems);
          } else {
            _selectedIndices.clear();
            _selectedIndices.add(index);
            _anchorIndex = index;
            _lastSelectedIndex = index;
            _previewItem = group;
            _previewIndex = index;
            _previewCarouselIndex = 0;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  item.thumbnail != null && item.isProfile
                      ? CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(item.thumbnail!),
                          backgroundColor: AppColors.violet.withOpacity(0.2),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.violet.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isPlaylist
                                ? Icons.playlist_play_rounded
                                : Icons.account_circle_rounded,
                            color: AppColors.violet,
                            size: 24,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPlaylist
                              ? (item.itemCount != null && item.itemCount! > 0
                                    ? '${item.itemCount} Videos'
                                    : 'Playlist')
                              : (item.itemCount != null && item.itemCount! > 0
                                    ? '${item.itemCount} Posts'
                                    : 'Profile'),
                          style: GoogleFonts.manrope(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.download_rounded,
                      color: AppColors.violet,
                      size: 20,
                    ),
                    onPressed: () => _startDownload(index),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _removeParsedItems([index]);
                      });
                    },
                  ),
                ],
              ),
              if (item.formats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Quality:',
                      style: GoogleFonts.manrope(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFormatDropdown(item, config, index)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTile(int index, MediaGroup group) {
    final item = group.first;
    final config = _configs[index]!;
    final isSelected = _selectedIndices.contains(index);

    String displayTitle = item.title;
    if (item.isProfile && displayTitle.toLowerCase() == 'item') {
      if (item.id != null && item.id!.isNotEmpty) {
        displayTitle = '@${item.id}';
      } else if (item.originalUrl != null) {
        try {
          final uri = Uri.parse(item.originalUrl!);
          if (uri.pathSegments.isNotEmpty) {
            displayTitle = '@${uri.pathSegments.first}';
          }
        } catch (_) {}
      }
    }

    return GestureDetector(
      onTap: () {
        _listFocusNode.requestFocus();
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        setState(() {
          if (isCtrl) {
            if (isSelected)
              _selectedIndices.remove(index);
            else
              _selectedIndices.add(index);
            _lastSelectedIndex = index;
            _anchorIndex = index;
          } else if (isShift && _anchorIndex != -1) {
            final items = _filteredItems;
            _lastSelectedIndex = index;
            _updateShiftSelection(items);
          } else {
            _selectedIndices.clear();
            _selectedIndices.add(index);
            _lastSelectedIndex = index;
            _anchorIndex = index;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D2D38) : const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.violet.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            // Removed IgnorePointer to allow interactions during hydration
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  Flexible(
                    flex: 0,
                    child: GestureDetector(
                      onTap:
                          _backgroundLoadingProfiles.contains(group.originalUrl)
                          ? null
                          : () {
                              setState(() {
                                _previewItem = group;
                                _previewIndex = index;
                                _previewCarouselIndex = 0;
                              });
                              _previewFocusNode.requestFocus();
                            },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              item.thumbnail != null
                                  ? Image.network(
                                      item.thumbnail!,
                                      width: 160,
                                      height: 104,
                                      fit: BoxFit.cover,
                                      headers: const {
                                        'User-Agent':
                                            'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
                                        'Referer': 'https://www.instagram.com/',
                                      },
                                      errorBuilder: (_, __, ___) =>
                                          item.isProfile
                                          ? Container(
                                              width: 160,
                                              height: 104,
                                              color: const Color(0xFF1E1E26),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.account_circle_rounded,
                                                  size: 40,
                                                  color: AppColors.violet,
                                                ),
                                              ),
                                            )
                                          : const FallbackThumb(),
                                    )
                                  : item.isProfile
                                  ? Container(
                                      width: 160,
                                      height: 104,
                                      color: const Color(0xFF1E1E26),
                                      child: const Center(
                                        child: Icon(
                                          Icons.account_circle_rounded,
                                          size: 40,
                                          color: AppColors.violet,
                                        ),
                                      ),
                                    )
                                  : const FallbackThumb(),
                              if (_backgroundLoadingProfiles.contains(
                                group.originalUrl,
                              ))
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.6),
                                    child: const Center(
                                      child: BubbleLoader(size: 40),
                                    ),
                                  ),
                                ),
                              if (item.extractor != null)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.extractor!,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    item.isProfile
                                        ? Icons.account_circle_rounded
                                        : (!group.isSingle
                                              ? Icons.filter_none_rounded
                                              : (item.isVideo
                                                    ? Icons.videocam_rounded
                                                    : Icons.image_rounded)),
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                              if (group.isSingle &&
                                  item.isVideo &&
                                  item.duration != null)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _formatDuration(item.duration!),
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!group.isSingle || item.isProfile)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Row(
                                    children: [
                                      if (group.imageCount > 0 ||
                                          item.isProfile)
                                        CountIndicator(
                                          icon: Icons.image_rounded,
                                          count: group.imageCount > 0
                                              ? group.imageCount
                                              : 0,
                                          disabled:
                                              config.groupFilter ==
                                              GroupDownloadType.videos,
                                        ),
                                      if ((group.imageCount > 0 ||
                                              item.isProfile) &&
                                          (group.videoCount > 0 ||
                                              item.isProfile))
                                        const SizedBox(width: 4),
                                      if (group.videoCount > 0 ||
                                          item.isProfile)
                                        CountIndicator(
                                          icon: Icons.videocam_rounded,
                                          count: group.videoCount > 0
                                              ? group.videoCount
                                              : 0,
                                          disabled:
                                              config.groupFilter ==
                                              GroupDownloadType.images,
                                        ),
                                    ],
                                  ),
                                )
                              else if (item.isProfile &&
                                  item.itemCount != null &&
                                  item.itemCount! > 0)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.itemCount} Posts',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!group.isSingle ||
                                  _getFileSize(item, config) != null)
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      !group.isSingle
                                          ? _formatBytes(
                                              _getGroupBytes(group, config),
                                            )
                                          : _getFileSize(item, config) ??
                                                'Unknown size',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title, Metadata, and Actions
                  Expanded(
                    child: SizedBox(
                      height: 104,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayTitle,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _removeParsedItems([index]);
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white38,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              CopyUrlButton(url: group.originalUrl ?? ''),
                            ],
                          ),

                          Builder(
                            builder: (context) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (group.isSingle &&
                                        item.formats.isNotEmpty)
                                      Flexible(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 130,
                                          ),
                                          child: _buildFormatDropdown(
                                            item,
                                            config,
                                            index,
                                          ),
                                        ),
                                      )
                                    else if (!group.isSingle || item.isProfile)
                                      Flexible(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 130,
                                          ),
                                          child: _buildGroupFilterDropdown(
                                            config,
                                            group,
                                          ),
                                        ),
                                      ),
                                    if ((group.isSingle &&
                                            item.formats.isNotEmpty) ||
                                        !group.isSingle ||
                                        item.isProfile)
                                      const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _startDownload(index),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.violet
                                            .withOpacity(0.2),
                                        foregroundColor: AppColors.violet,
                                        elevation: 0,
                                        fixedSize: const Size.fromHeight(32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        (!group.isSingle ||
                                                item.isProfile ||
                                                item.isPlaylist)
                                            ? 'Download All'
                                            : 'Download',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeRadio(
    int index,
    DownloadConfig config,
    DownloadMode mode,
    String label,
  ) {
    final isSelected = config.mode == mode;
    return InkWell(
      onTap: () {
        setState(() => config.mode = mode);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.white38,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatDropdown(
    MediaInfo item,
    DownloadConfig config,
    int index, {
    bool isItemLevel = false,
  }) {
    var formats = item.formats.toSet().toList();

    formats.sort((a, b) {
      final aAudio =
          a.resolution == 'audio only' || a.resolution.toLowerCase() == 'audio';
      final bAudio =
          b.resolution == 'audio only' || b.resolution.toLowerCase() == 'audio';
      if (aAudio != bAudio) return aAudio ? 1 : -1;
      return _getHeight(b.resolution).compareTo(_getHeight(a.resolution));
    });

    final maxH = formats.fold<int>(0, (max, f) {
      final h = _getHeight(f.resolution);
      return h > max ? h : max;
    });

    if (maxH >= 480) {
      formats = formats.where((f) {
        if (f.resolution == 'audio only' ||
            f.resolution.toLowerCase() == 'audio')
          return true;
        return _getHeight(f.resolution) >= 480;
      }).toList();
    }

    final currentFormat = isItemLevel
        ? config.itemFormats[item.id] ?? config.format
        : config.format;

    final hasMultiple = formats.length > 1;
    final displayFormat = formats.contains(currentFormat)
        ? currentFormat
        : (formats.isNotEmpty ? formats.first : null);

    return PopupMenuButton<MediaFormat>(
      enabled: hasMultiple,
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
          if (isItemLevel) {
            config.itemFormats[item.id] = val;
          } else {
            config.format = val;
          }
        });
      },
      itemBuilder: (context) => formats.map((f) {
        final isSelected = f == currentFormat;
        return PopupMenuItem<MediaFormat>(
          value: f,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_formatResolution(f.resolution)} (${f.extension})',
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
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
          color: Colors.white.withOpacity(hasMultiple ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(hasMultiple ? 0.1 : 0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayFormat != null
                    ? '${_formatResolution(displayFormat.resolution)} (${displayFormat.extension})'
                    : 'Select',
                style: GoogleFonts.manrope(
                  color: hasMultiple ? Colors.white : Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasMultiple)
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
