part of '../downloads_panel.dart';

extension DownloadsPanelResultsView on _MediaDownloaderPanelState {
  List<MapEntry<int, MediaGroup>> get _filteredItems {
    if (_parsedItems == null) return [];
    var entries = _parsedItems!.asMap().entries.toList();

    if (_sortFilter == 'image') {
      entries = entries
          .where((e) => !e.value.first.isVideo && !e.value.first.isPlaylist && !e.value.first.isProfile)
          .toList();
    } else if (_sortFilter == 'video') {
      entries = entries
          .where((e) => e.value.first.isVideo && !e.value.first.isPlaylist && !e.value.first.isProfile)
          .toList();
    } else if (_sortFilter == 'playlist') {
      entries = entries
          .where((e) => e.value.first.isPlaylist && !e.value.first.isProfile)
          .toList();
    } else if (_sortFilter == 'profile') {
      entries = entries
          .where((e) => e.value.first.isProfile)
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
    final sortOptions = [
      {'value': 'added_desc', 'label': 'Added', 'icon': Icons.arrow_upward_rounded},
      {'value': 'added_asc', 'label': 'Added', 'icon': Icons.arrow_downward_rounded},
      {'value': 'size_desc', 'label': 'Size', 'icon': Icons.arrow_upward_rounded},
      {'value': 'size_asc', 'label': 'Size', 'icon': Icons.arrow_downward_rounded},
      {'value': 'image', 'label': 'Images', 'icon': Icons.image_outlined},
      {'value': 'video', 'label': 'Videos', 'icon': Icons.videocam_outlined},
      {'value': 'playlist', 'label': 'Playlists', 'icon': Icons.queue_music_rounded},
      {'value': 'profile', 'label': 'Profiles', 'icon': Icons.person_outline_rounded},
    ];
    final activeSortOpt = sortOptions.firstWhere((opt) => opt['value'] == _sortFilter, orElse: () => sortOptions.first);

    final displayItems = _filteredItems;
    final hasItems = _parsedItems != null && _parsedItems!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Tooltip(
                            message: _importedListName ?? 'Fetched Media',
                            waitDuration: const Duration(milliseconds: 500),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            textStyle: GoogleFonts.manrope(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                            child: Text(
                              _importedListName ?? 'Fetched Media',
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_importedListName != null) ...[
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                setState(() {
                                  _parsedItems?.clear();
                                  _configs.clear();
                                  _selectedIndices.clear();
                                  _lastSelectedIndex = -1;
                                  _previewItem = null;
                                  _importedListName = null;
                                  _importedListPath = null;
                                  _isListChanged = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _sortFilter != 'added_desc' 
                          ? AppColors.violet.withOpacity(0.1) 
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _sortFilter != 'added_desc' 
                            ? AppColors.violet.withOpacity(0.5) 
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: PopupMenuButton<String>(
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
                        _setSortFilter(val);
                      },
                      itemBuilder: (context) {
                        return sortOptions.map((opt) {
                          final isSelected = _sortFilter == opt['value'];
                          return PopupMenuItem<String>(
                            value: opt['value'] as String,
                            height: 40,
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
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            activeSortOpt['icon'] as IconData,
                            size: 16,
                            color: _sortFilter != 'added_desc' 
                                ? AppColors.violet 
                                : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activeSortOpt['label'] as String,
                            style: GoogleFonts.manrope(
                              color: _sortFilter != 'added_desc' ? AppColors.violet : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (_sortFilter != 'added_desc')
                            GestureDetector(
                              onTap: () {
                                _setSortFilter('added_desc');
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                            )
                          else
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Selection Actions (Clear)
              IgnorePointer(
                ignoring: !hasItems,
                child: Opacity(
                  opacity: hasItems ? 1.0 : 0.4,
                  child: Container(
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
                            _isListChanged = true;
                          }
                        });
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 16),
                      label: Text(
                        _selectedIndices.isNotEmpty
                            ? 'Clear ${_selectedIndices.length}'
                            : 'Clear',
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
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        // Statistics Strip
        if (hasItems)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.sd_storage_rounded, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  StringUtils.formatBytes(_totalListSize),
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 20),
                Icon(Icons.image_outlined, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  '$_totalListImages Images',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 20),
                Icon(Icons.videocam_outlined, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  '$_totalListVideos Videos',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        // List View
        Expanded(
          child: DragTarget<List<String>>(
            onWillAcceptWithDetails: (details) {
              setState(() => _isDraggingFile = true);
              return true;
            },
            onLeave: (_) {
              setState(() => _isDraggingFile = false);
            },
            onAcceptWithDetails: (details) async {
              setState(() => _isDraggingFile = false);
              if ((_parsedItems != null && _parsedItems!.isNotEmpty) || _importedListPath != null) {
                _showLocalToast('Please clear the list before importing');
                return;
              }
              if (details.data.isNotEmpty) {
                final path = details.data.first;
                if (path.toLowerCase().endsWith('.json')) {
                  await _importList(path);
                } else {
                  _showLocalToast('Only JSON files are supported');
                }
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Critical for hit-testing the Drag-and-Drop over empty space
                  Container(color: Colors.transparent),
              displayItems.isEmpty
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
                        const SingleActivator(
                          LogicalKeyboardKey.arrowDown,
                        ): () {
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
                        const SingleActivator(
                          LogicalKeyboardKey.arrowUp,
                        ): () {
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
              if (_isDraggingFile)
                IgnorePointer(
                  child: Builder(
                    builder: (context) {
                      final hasConflict = (_parsedItems != null && _parsedItems!.isNotEmpty) || _importedListPath != null;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasConflict 
                              ? [Colors.black.withOpacity(0.85), Colors.black.withOpacity(0.85)]
                              : [AppColors.violet.withOpacity(0.15), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _gradientController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _GradientBorderPainter(
                                  _gradientController.value,
                                  radius: 16.0,
                                  strokeWidth: 2.0,
                                  colors: hasConflict 
                                    ? [Colors.redAccent, Colors.orangeAccent, Colors.red, Colors.redAccent]
                                    : [AppColors.magenta, AppColors.violet, AppColors.indigo, AppColors.magenta],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceBase.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) => LinearGradient(
                                            colors: hasConflict 
                                              ? [Colors.redAccent, Colors.orangeAccent]
                                              : [AppColors.magenta, AppColors.violet, AppColors.indigo],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                          child: Icon(
                                            hasConflict
                                                ? Icons.error_outline
                                                : Icons.download_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          hasConflict
                                              ? 'Please clear the list before importing'
                                              : 'Drop JSON list to import',
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Bottom Block (Controls + Drawer)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
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
                          ignoring: _importedListPath != null
                              ? !_isListChanged
                              : !hasItems,
                          child: Opacity(
                            opacity:
                                (_importedListPath != null
                                    ? !_isListChanged
                                    : !hasItems)
                                ? 0.4
                                : 1.0,
                            child: ElevatedButton.icon(
                              onPressed: _importedListPath != null
                                  ? _updateList
                                  : _exportList,
                              icon: Icon(
                                _importedListPath != null
                                    ? Icons.save_alt
                                    : Icons.file_download_outlined,
                                size: 16,
                              ),
                              label: Text(
                                _importedListPath != null
                                    ? 'Update List'
                                    : 'Export List',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A35),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
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
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                        ),
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
