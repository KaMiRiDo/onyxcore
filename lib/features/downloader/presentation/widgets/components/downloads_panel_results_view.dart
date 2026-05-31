part of '../downloads_panel.dart';

extension DownloadsPanelResultsView on _MediaDownloaderPanelState {
  List<MapEntry<int, MediaGroup>> get _filteredItems {
    if (_parsedItems == null) return [];
    var entries = _parsedItems!.asMap().entries.toList();

    // First apply filters
    if (_sortFilter == 'image') {
      entries = entries
          .where((e) => !e.value.first.isVideo && !e.value.first.isPlaylist)
          .toList();
    } else if (_sortFilter == 'video') {
      entries = entries
          .where((e) => e.value.first.isVideo && !e.value.first.isPlaylist)
          .toList();
    }

    // Then apply sorting (added_desc is default, meaning newest at top. Assuming parse order is old -> new, so reverse order)
    if (_sortFilter == 'added_asc') {
      entries.sort((a, b) => a.key.compareTo(b.key));
    } else if (_sortFilter == 'size_asc' || _sortFilter == 'size_desc') {
      entries.sort((a, b) {
        final aSize = a.value.totalFilesize;
        final bSize = b.value.totalFilesize;
        return _sortFilter == 'size_asc'
            ? aSize.compareTo(bSize)
            : bSize.compareTo(aSize);
      });
    } else {
      // added_desc
      entries.sort((a, b) => b.key.compareTo(a.key));
    }

    return entries;
  }

  Widget _buildResultsView() {
    final displayItems = _filteredItems;
    final hasItems = _parsedItems != null && _parsedItems!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Fetched Media',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              // Filter Dropdown
              IgnorePointer(
                ignoring: !hasItems,
                child: Opacity(
                  opacity: hasItems ? 1.0 : 0.4,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortFilter,
                        icon: const Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        items:
                            [
                              {
                                'value': 'added_desc',
                                'label': 'Added',
                                'icon': Icons.arrow_upward_rounded,
                              },
                              {
                                'value': 'added_asc',
                                'label': 'Added',
                                'icon': Icons.arrow_downward_rounded,
                              },
                              {
                                'value': 'size_asc',
                                'label': 'Size',
                                'icon': Icons.arrow_upward_rounded,
                              },
                              {
                                'value': 'size_desc',
                                'label': 'Size',
                                'icon': Icons.arrow_downward_rounded,
                              },
                              {
                                'value': 'image',
                                'label': 'Image',
                                'icon': Icons.image_rounded,
                              },
                              {
                                'value': 'video',
                                'label': 'Video',
                                'icon': Icons.videocam_rounded,
                              },
                            ].map((item) {
                              return DropdownMenuItem<String>(
                                value: item['value'] as String,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item['icon'] as IconData,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(item['label'] as String),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sortFilter = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Clear All Button
              IgnorePointer(
                ignoring: !hasItems,
                child: Opacity(
                  opacity: hasItems ? 1.0 : 0.4,
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.isNotEmpty) {
                            _removeParsedItems(_selectedIndices.toList());
                          } else {
                            _parsedItems?.clear();
                            _configs.clear();
                            _selectedIndices.clear();
                            _lastSelectedIndex = -1;
                            _previewItem = null;
                          }
                        });
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 16),
                      label: Text(
                        _selectedIndices.isNotEmpty
                            ? 'Clear ${_selectedIndices.length}'
                            : 'Clear All',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize
                            .shrinkWrap, // Removes hidden invisible padding
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // List View
        Expanded(
          child: displayItems.isEmpty
              ? const DownloadsEmptyState()
              : CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () {
                      setState(() {
                        _selectedIndices.clear();
                        _anchorIndex = -1;
                        _previewItem = null;
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.delete): () {
                      if (_selectedIndices.isNotEmpty) {
                        setState(() {
                          _removeParsedItems(_selectedIndices.toList());
                        });
                      }
                    },
                    const SingleActivator(
                      LogicalKeyboardKey.keyA,
                      control: true,
                    ): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isNotEmpty) {
                          _selectedIndices.clear();
                          for (var item in items) {
                            _selectedIndices.add(item.key);
                          }
                          _anchorIndex = items.first.key;
                          _lastSelectedIndex = items.last.key;
                        }
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex < items.length - 1) {
                          _lastSelectedIndex =
                              items[currentVisualIndex + 1].key;
                          _anchorIndex = _lastSelectedIndex;
                          _selectedIndices.clear();
                          _selectedIndices.add(_lastSelectedIndex);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                    const SingleActivator(
                      LogicalKeyboardKey.arrowDown,
                      shift: true,
                    ): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        if (_anchorIndex == -1)
                          _anchorIndex = _lastSelectedIndex;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex < items.length - 1) {
                          _lastSelectedIndex =
                              items[currentVisualIndex + 1].key;
                          _updateShiftSelection(items);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex > 0) {
                          _lastSelectedIndex =
                              items[currentVisualIndex - 1].key;
                          _anchorIndex = _lastSelectedIndex;
                          _selectedIndices.clear();
                          _selectedIndices.add(_lastSelectedIndex);
                          _scrollToIndex(_lastSelectedIndex);
                        } else if (currentVisualIndex == -1 &&
                            items.isNotEmpty) {
                          _lastSelectedIndex = items.last.key;
                          _anchorIndex = _lastSelectedIndex;
                          _selectedIndices.clear();
                          _selectedIndices.add(_lastSelectedIndex);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                    const SingleActivator(
                      LogicalKeyboardKey.arrowUp,
                      shift: true,
                    ): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        if (_anchorIndex == -1)
                          _anchorIndex = _lastSelectedIndex;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex > 0) {
                          _lastSelectedIndex =
                              items[currentVisualIndex - 1].key;
                          _updateShiftSelection(items);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                  },
                  child: Focus(
                    focusNode: _listFocusNode,
                    autofocus: false,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: displayItems.length,
                      itemBuilder: (context, listIndex) {
                        final entry = displayItems[listIndex];
                        final index = entry.key;
                        final item = entry.value;
                        final key = _itemKeys.putIfAbsent(
                          index,
                          () => GlobalKey(),
                        );

                        Widget tile;
                        if (item.first.isPlaylist) {
                          tile = _buildGroupTile(index, item);
                        } else {
                          tile = _buildMediaTile(index, item);
                        }
                        return Container(key: key, child: tile);
                      },
                    ),
                  ),
                ),
        ),
        // Bottom Block (Controls + Drawer)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Controls Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IgnorePointer(
                          ignoring: !hasItems,
                          child: Opacity(
                            opacity: hasItems ? 1.0 : 0.4,
                            child: _buildLocationDropdown(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      width: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isDownloadsDrawerOpen =
                                    !_isDownloadsDrawerOpen;
                              });
                            },
                            icon: const Icon(
                              Icons.downloading_rounded,
                              color: AppColors.violet,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.violet.withOpacity(
                                0.1,
                              ),
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            tooltip: 'Active Downloads',
                          ),
                          if (!_isDownloadsDrawerOpen)
                            Positioned(
                              top: -18,
                              child: Transform.scale(
                                scaleX: 1.4,
                                scaleY: 0.8,
                                child: const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: AppColors.violet,
                                  size: 24,
                                ),
                              ),
                            ),
                          if (_isDownloadsDrawerOpen)
                            Positioned(
                              bottom: -18,
                              child: Transform.scale(
                                scaleX: 1.4,
                                scaleY: 0.8,
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.violet,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IgnorePointer(
                          ignoring: !hasItems,
                          child: Opacity(
                            opacity: hasItems ? 1.0 : 0.4,
                            child: ElevatedButton.icon(
                              onPressed: _startDownloadAll,
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _selectedIndices.isNotEmpty
                                    ? 'Download ${_selectedIndices.length}'
                                    : 'Download All',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.violet,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 2. Drawer Content
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.bottomCenter,
                child: !_isDownloadsDrawerOpen
                    ? const SizedBox(width: double.infinity, height: 0)
                    : SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.34,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Active Downloads',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final activeTasks = ref.watch(
                                        activeDownloadTaskProvider,
                                      );
                                      if (activeTasks.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.download_done_rounded,
                                                color: Colors.white24,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'No active downloads',
                                                style: GoogleFonts.manrope(
                                                  color: Colors.white54,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return ListView.builder(
                                        padding: const EdgeInsets.only(top: 8),
                                        itemCount: activeTasks.length,
                                        itemBuilder: (context, index) {
                                          return DownloadTaskTile(
                                            task: activeTasks[index],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
