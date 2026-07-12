part of '../downloads_panel.dart';

extension DownloadsPanelTiles on _MediaDownloaderPanelState {
  Widget _buildErrorTile(int index, MediaGroup group) {
    final item = group.first;
    final isSelected = _selectedIndices.contains(index);

    return GestureDetector(
      onTap: () {
        _listFocusNode.requestFocus();
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        setState(() {
          if (isCtrl) {
            if (isSelected) {
              _selectedIndices.remove(index);
            } else {
              _selectedIndices.add(index);
            }
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
          color: isSelected ? const Color(0xFF382020) : const Color(0xFF2A1515),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.redAccent.withValues(alpha: 0.5)
                : Colors.redAccent.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title.isNotEmpty
                              ? item.title
                              : 'Error Processing URL',
                          style: GoogleFonts.manrope(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.originalUrl,
                          style: GoogleFonts.manrope(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.errorMessage != null &&
                            item.errorMessage!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.errorMessage!,
                            style: GoogleFonts.manrope(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                _showLogs(item);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color:
                                      (item.errorMessage != null &&
                                          item.errorMessage!.isNotEmpty)
                                      ? Colors.redAccent
                                      : AppColors.violet,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CopyUrlButton(
                              url:
                                  item.webpageUrl ??
                                  item.directUrl ??
                                  item.originalUrl,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _removeParsedItems([index]);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: Colors.white38, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTile(int index, MediaGroup group) {
    final item = group.first;
    if (item.isError) return _buildErrorTile(index, group);

    final config = _configs[index]!;
    final isSelected = _selectedIndices.contains(index);

    var displayTitle = item.title;
    if (item.isProfile && displayTitle.toLowerCase() == 'item') {
      if (item.id.isNotEmpty) {
        displayTitle = '@${item.id}';
      } else {
        try {
          final uri = Uri.parse(item.originalUrl);
          if (uri.pathSegments.isNotEmpty) {
            displayTitle = '@${uri.pathSegments.first}';
          }
        } catch (_) {}
      }
    }

    var sourceBadgeName = item.extractor;
    if (sourceBadgeName == null || sourceBadgeName.toLowerCase() == 'generic') {
      try {
        final urlStr = group.originalUrl;
        final uri = Uri.parse(urlStr);
        sourceBadgeName = uri.host.replaceFirst('www.', '');
      } catch (_) {
        sourceBadgeName = 'Web';
      }
    }
    if (sourceBadgeName.length > 15) {
      sourceBadgeName = '${sourceBadgeName.substring(0, 12)}...';
    }

    return GestureDetector(
      onTap: () {
        _listFocusNode.requestFocus();
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        setState(() {
          if (isCtrl) {
            if (isSelected) {
              _selectedIndices.remove(index);
            } else {
              _selectedIndices.add(index);
            }
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
                ? AppColors.violet.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: item.id == 'fetch_loading',
              child: Padding(
                padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  Flexible(
                    flex: 0,
                    child: GestureDetector(
                      onTap: () {
                        if ((item.isProfile || item.isPlaylist) &&
                            group.isSingle &&
                            !_backgroundLoadingProfiles.contains(
                              group.originalUrl,
                            )) {
                          _hydrateProfile(group.originalUrl);
                        } else {
                          setState(() {
                            _previewItem = group;
                            _previewIndex = index;
                            _previewCarouselIndex = 0;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _previewFocusNode.requestFocus();
                          });
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              if (item.thumbnail != null) item.thumbnail!.startsWith('data:image')
                                        ? Image.memory(
                                            base64Decode(
                                              item.thumbnail!.split(',').last,
                                            ),
                                            width: 160,
                                            height: 104,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            item.thumbnail!,
                                            width: 160,
                                            height: 104,
                                            fit: BoxFit.cover,
                                            headers: const {
                                              'User-Agent':
                                                  'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
                                              'Referer':
                                                  'https://www.instagram.com/',
                                            },
                                            loadingBuilder:
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    width: 160,
                                                    height: 104,
                                                    color: Colors.black12,
                                                    child: const Center(
                                                      child:
                                                          _JugglingBallsLoader(),
                                                    ),
                                                  );
                                                },
                                            errorBuilder: (_, __, ___) =>
                                                item.isProfile
                                                ? Container(
                                                    width: 160,
                                                    height: 104,
                                                    color: const Color(
                                                      0xFF1E1E26,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .account_circle_rounded,
                                                        size: 40,
                                                        color: AppColors.violet,
                                                      ),
                                                    ),
                                                  )
                                                : item.isPlaylist
                                                ? Container(
                                                    width: 160,
                                                    height: 104,
                                                    color: const Color(
                                                      0xFF1E1E26,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .video_library_rounded,
                                                        size: 40,
                                                        color: AppColors.violet,
                                                      ),
                                                    ),
                                                  )
                                                : const FallbackThumb(),
                                          ) else item.isProfile
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
                                  : item.isPlaylist
                                  ? Container(
                                      width: 160,
                                      height: 104,
                                      color: const Color(0xFF1E1E26),
                                      child: const Center(
                                        child: Icon(
                                          Icons.playlist_play_rounded,
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
                                  child: ColoredBox(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: const Center(
                                      child: BubbleLoader(size: 40),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sourceBadgeName,
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
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    item.isProfile
                                        ? Icons.account_circle_rounded
                                        : item.isPlaylist
                                        ? Icons.video_library_rounded
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
                              if (group.isSingle && item.isVideo)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.duration != null
                                          ? _formatDuration(item.duration!)
                                          : '--:--',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (!group.isSingle ||
                                  item.isProfile ||
                                  item.isPlaylist)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _hydrationNotifier,
                                    builder: (context, _, __) {
                                      return Row(
                                        children: [
                                          if ((group.imageCount > 0 ||
                                                  item.isProfile) &&
                                              !item.isPlaylist)
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
                                                  item.isProfile ||
                                                  item.isPlaylist))
                                            const SizedBox(width: 4),
                                          if (group.videoCount > 0 ||
                                              item.isProfile ||
                                              item.isPlaylist)
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
                                      );
                                    },
                                  ),
                                )
                              else if (item.isProfile)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${group.items.length > 1 ? group.items.length - 1 : 0} Posts',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _hydrationNotifier,
                                    builder: (context, _, __) {
                                      return Text(
                                        !group.isSingle
                                            ? _formatBytes(
                                                _getGroupBytes(group, config),
                                              )
                                            : ((item.isPlaylist ||
                                                      item.isProfile)
                                                  ? '0 B'
                                                  : (_getFileSize(
                                                          item,
                                                          config,
                                                        ) ??
                                                        'Unknown size')),
                                        style: GoogleFonts.manrope(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
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
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _showLogs(item);
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color:
                                            (item.errorMessage != null &&
                                                item.errorMessage!.isNotEmpty)
                                            ? Colors.redAccent
                                            : AppColors.violet,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Builder(
                                    builder: (context) {
                                      final engineObj = EngineRegistry.findById(
                                        config.engine,
                                      );
                                      if (engineObj == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            engineObj.icon,
                                            size: 12,
                                            color: engineObj.color,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            engineObj.displayName,
                                            style: GoogleFonts.manrope(
                                              color: engineObj.color
                                                  .withValues(alpha: 0.8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Text(
                                              '•',
                                              style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  CopyUrlButton(url: group.originalUrl),
                                ],
                              ),
                            ],
                          ),

                          Builder(
                            builder: (context) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if ((group.isSingle &&
                                            item.formats.isNotEmpty) ||
                                        item.isPlaylist)
                                      Flexible(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 130,
                                          ),
                                          child: FormatSelectionDropdown(
                                            item: item,
                                            config: config,
                                            index: index,
                                            group: group,
                                            getHeight: _getHeight,
                                            matchTargetFormat: matchTargetFormat,
                                            onChanged: (val) {
                                              setState(() {
                                                config.format = val;
                                              });
                                            },
                                          ),
                                        ),
                                      )
                                    else if (!group.isSingle || item.isProfile)
                                      Flexible(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 130,
                                          ),
                                          child: GroupFilterDropdown(
                                            selectedFilter: config.groupFilter,
                                            isEnabled: group.first.isProfile || (group.items.any((item) => !item.isVideo) && group.items.any((item) => item.isVideo)),
                                            onChanged: (val) {
                                              setState(() {
                                                config.groupFilter = val;
                                                _previewCarouselIndex = 0;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    if ((group.isSingle &&
                                            item.formats.isNotEmpty) ||
                                        item.isPlaylist ||
                                        !group.isSingle ||
                                        item.isProfile)
                                      const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _startDownload(index),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.violet
                                            .withValues(alpha: 0.2),
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
            ),
            if (item.id == 'fetch_loading')
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.65),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            height: 24,
                            child: _JugglingBallsLoader(),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Analyzing ${item.originalUrl}...',
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (item.id == 'fetch_loading')
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _removeParsedItems([index]);
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white54, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
