part of '../downloads_panel.dart';

extension DownloadsPanelPreview on _MediaDownloaderPanelState {
  Widget _buildSinglePreviewOverlay() {
    final item = _previewItem;
    if (item == null) return const SizedBox.shrink();
    final index = _previewIndex;
    if (index == null) return const SizedBox.shrink();
    final config = _configs[index];
    if (config == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _previewItem = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withOpacity(
            0.8,
          ), // Made the background more shaded
          child: Center(
            child: GestureDetector(
              onTap:
                  () {}, // Absorb taps on the dialog itself so it doesn't close
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C35).withOpacity(
                        0.85,
                      ), // Lighter, more visible glassmorphism shade
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ), // Stronger border to help it pop
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header (cross button)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _previewItem = null;
                              });
                            },
                          ),
                        ),
                        // Image area
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 210,
                            ), // Slightly reduced thumbnail size
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                item.first.thumbnail != null
                                    ? (item.first.thumbnail!.startsWith(
                                            'data:image',
                                          )
                                          ? Image.memory(
                                              base64Decode(
                                                item.first.thumbnail!
                                                    .split(',')
                                                    .last,
                                              ),
                                              fit: BoxFit.contain,
                                            )
                                          : Image.network(
                                              item.first.thumbnail!,
                                              fit: BoxFit.contain,
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
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return const SizedBox(
                                                      height: 210,
                                                      child: Center(
                                                        child:
                                                            _JugglingBallsLoader(),
                                                      ),
                                                    );
                                                  },
                                              errorBuilder: (_, __, ___) =>
                                                  const FallbackThumb(),
                                            ))
                                    : const FallbackThumb(),
                                if (item.isSingle && item.first.isVideo)
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.first.duration != null
                                            ? _formatDuration(
                                                item.first.duration!,
                                              )
                                            : '--:--',
                                        style: GoogleFonts.manrope(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Details
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.first.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item.first.extractor != null) ...[
                                    Text(
                                      item.first.extractor!,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
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
                                  Text(
                                    !item.isSingle
                                        ? _formatBytes(
                                            _getGroupBytes(item, config),
                                          )
                                        : (_getFileSize(item.first, config) ??
                                              'Unknown size'),
                                    style: GoogleFonts.manrope(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  CopyUrlButton(
                                    url:
                                        item.first.directUrl ??
                                        item.first.originalUrl,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Controls footer
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Row(
                            children: [
                              if (item.isSingle &&
                                  item.first.formats.isNotEmpty)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 210,
                                      child: _buildFormatDropdown(
                                        item.first,
                                        config,
                                        index,
                                      ),
                                    ),
                                  ),
                                )
                              else if (!item.isSingle)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 210,
                                      child: _buildGroupFilterDropdown(
                                        config,
                                        item,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _removeParsedItems([index]);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.05,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  fixedSize: const Size.fromHeight(32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Remove',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _startDownload(index);
                                  setState(() {
                                    _previewItem = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.violet.withOpacity(
                                    0.2,
                                  ),
                                  foregroundColor: AppColors.violet,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  fixedSize: const Size.fromHeight(32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  (!item.isSingle ||
                                          item.first.isProfile ||
                                          item.first.isPlaylist)
                                      ? 'Download All'
                                      : 'Download',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPreviewOverlay() {
    final group = _previewItem;
    if (group == null) return const SizedBox.shrink();
    final groupIndex = _previewIndex;
    if (groupIndex == null) return const SizedBox.shrink();
    final config = _configs[groupIndex];
    if (config == null) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: _hydrationNotifier,
      builder: (context, _, __) {
        final visibleItems = _visiblePreviewItems;

        String displayTitle = group.first.title;
        if (group.first.isProfile && displayTitle.toLowerCase() == 'item') {
          if (group.first.id != null && group.first.id!.isNotEmpty) {
            displayTitle = '@${group.first.id}';
          } else if (group.first.originalUrl != null) {
            try {
              final uri = Uri.parse(group.first.originalUrl!);
              if (uri.pathSegments.isNotEmpty) {
                displayTitle = '@${uri.pathSegments.first}';
              }
            } catch (_) {}
          }
        }

        // Safety fallback
        if (visibleItems.isEmpty) {
          return const SizedBox.shrink();
        }
        if (_previewCarouselIndex >= visibleItems.length) {
          _previewCarouselIndex = visibleItems.length - 1;
        }
        if (_previewCarouselIndex < 0) {
          _previewCarouselIndex = 0;
        }

        final currentItem = visibleItems[_previewCarouselIndex];
        final totalSize = visibleItems.fold<int>(
          0,
          (sum, i) => sum + (i.filesize ?? 0),
        );

        return Positioned.fill(
          child: Focus(
            focusNode: _previewFocusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  if (_previewCarouselIndex > 0) {
                    setState(() {
                      _previewCarouselIndex--;
                    });
                    return KeyEventResult.handled;
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (_previewCarouselIndex < visibleItems.length - 1) {
                    setState(() {
                      _previewCarouselIndex++;
                    });
                    return KeyEventResult.handled;
                  }
                }
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _previewItem = null;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // Absorb taps
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          width: 650, // Fixed width for better carousel look
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C35).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Row 1: Title and Close Button
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.manrope(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              _previewItem = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Row 2: Source • Size
                                    Row(
                                      children: [
                                        if (group.first.extractor != null) ...[
                                          Text(
                                            group.first.extractor!,
                                            style: GoogleFonts.manrope(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              '•',
                                              style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                        Text(
                                          _formatBytes(totalSize),
                                          style: GoogleFonts.manrope(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Row 3: Dropdown & Download All
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        SizedBox(
                                          width: 210,
                                          child: group.first.isPlaylist
                                              ? _buildFormatDropdown(
                                                  group.first,
                                                  config,
                                                  groupIndex,
                                                  group: group,
                                                )
                                              : _buildGroupFilterDropdown(
                                                  config,
                                                  group,
                                                ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            _startDownload(groupIndex);
                                            setState(() {
                                              _previewItem = null;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.violet
                                                .withOpacity(0.2),
                                            foregroundColor: AppColors.violet,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            fixedSize: const Size.fromHeight(
                                              32,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    8,
                                                  ),
                                            ),
                                          ),
                                          child: Text(
                                            'Download All',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Image Carousel
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  children: [
                                    // Prev Button
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_back_ios,
                                        color: _previewCarouselIndex > 0
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                                      onPressed: _previewCarouselIndex > 0
                                          ? () {
                                              setState(() {
                                                _previewCarouselIndex--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Expanded(
                                      child: SizedBox(
                                        height: 280,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            currentItem.id ==
                                                    'hydration_loading'
                                                ? Container(
                                                    color: Colors.black
                                                        .withOpacity(0.6),
                                                    child: const Center(
                                                      child:
                                                          _JugglingBallsLoader(),
                                                    ),
                                                  )
                                                : currentItem.thumbnail != null
                                                ? (currentItem.thumbnail!
                                                          .startsWith(
                                                            'data:image',
                                                          )
                                                      ? Image.memory(
                                                          base64Decode(
                                                            currentItem
                                                                .thumbnail!
                                                                .split(',')
                                                                .last,
                                                          ),
                                                          fit: BoxFit.contain,
                                                        )
                                                      : Image.network(
                                                          currentItem
                                                              .thumbnail!,
                                                          fit: BoxFit.contain,
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
                                                                if (loadingProgress ==
                                                                    null)
                                                                  return child;
                                                                return Center(
                                                                  child: CircularProgressIndicator(
                                                                    color: AppColors
                                                                        .violet
                                                                        .withOpacity(
                                                                          0.5,
                                                                        ),
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                );
                                                              },
                                                          errorBuilder: (_, __, ___) =>
                                                              group
                                                                  .first
                                                                  .isProfile
                                                              ? Container(
                                                                  color: const Color(
                                                                    0xFF1E1E26,
                                                                  ),
                                                                  child: const Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .account_circle_rounded,
                                                                      size: 80,
                                                                      color: AppColors
                                                                          .violet,
                                                                    ),
                                                                  ),
                                                                )
                                                              : const FallbackThumb(),
                                                        ))
                                                : group.first.isProfile
                                                ? Container(
                                                    color: const Color(
                                                      0xFF1E1E26,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .account_circle_rounded,
                                                        size: 80,
                                                        color: AppColors.violet,
                                                      ),
                                                    ),
                                                  )
                                                : const FallbackThumb(),
                                            if (currentItem.isVideo)
                                              Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(
                                                          0.7,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    currentItem.duration != null
                                                        ? _formatDuration(
                                                            currentItem
                                                                .duration!,
                                                          )
                                                        : '--:--',
                                                    style: GoogleFonts.manrope(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(
                                                        0.7,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${_previewCarouselIndex + 1} / ${visibleItems.length}',
                                                  style: GoogleFonts.manrope(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if ((currentItem.isPlaylist ||
                                                    currentItem.isProfile) &&
                                                _backgroundLoadingProfiles
                                                    .contains(
                                                      group.originalUrl,
                                                    ))
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(
                                                          0.6,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Center(
                                                    child:
                                                        _JugglingBallsLoader(),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Next Button
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_forward_ios,
                                        color:
                                            _previewCarouselIndex <
                                                visibleItems.length - 1
                                            ? Colors.white
                                            : Colors.white24,
                                      ),
                                      onPressed:
                                          _previewCarouselIndex <
                                              visibleItems.length - 1
                                          ? () {
                                              setState(() {
                                                _previewCarouselIndex++;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              // Footer
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _trimMiddle(currentItem.title, 40) +
                                          ' (${_getFileSize(currentItem, config) ?? "Unknown size"})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    CopyUrlButton(
                                      url:
                                          currentItem.directUrl ??
                                          currentItem.originalUrl,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        if (currentItem.formats.isNotEmpty)
                                          SizedBox(
                                            width: 210,
                                            child: _buildFormatDropdown(
                                              currentItem,
                                              config,
                                              groupIndex,
                                              isItemLevel: true,
                                            ),
                                          )
                                        else
                                          const Spacer(),
                                        const Spacer(),
                                        OutlinedButton(
                                          onPressed: () {
                                            _removeSingleItem(
                                              groupIndex,
                                              currentItem.id,
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                            backgroundColor: Colors.white
                                                .withOpacity(0.05),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            fixedSize: const Size.fromHeight(
                                              32,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    8,
                                                  ),
                                            ),
                                          ),
                                          child: Text(
                                            'Remove',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            _startDownload(
                                              groupIndex,
                                              singleItemId: currentItem.id,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.violet
                                                .withOpacity(0.2),
                                            foregroundColor: AppColors.violet,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            fixedSize: const Size.fromHeight(
                                              32,
                                            ),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    8,
                                                  ),
                                            ),
                                          ),
                                          child: Text(
                                            'Download',
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
