part of '../downloads_panel.dart';

extension DownloadsPanelInputView on _MediaDownloaderPanelState {
  Widget _buildInputView() {
    final hasItems = _parsedItems != null && _parsedItems!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  final isFocused = _urlFocusNode.hasFocus;
                  return CustomPaint(
                    painter: isFocused
                        ? _GradientBorderPainter(_gradientController.value)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: !isFocused
                            ? Border.all(color: Colors.white10)
                            : Border.all(color: Colors.transparent, width: 1.5),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.keyA &&
                          HardwareKeyboard.instance.isControlPressed) {
                        _urlController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _urlController.text.length,
                        );
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.enter &&
                          HardwareKeyboard.instance.isControlPressed) {
                        _analyzeUrls();
                        return KeyEventResult.handled;
                      }

                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        if (_parsedItems != null && _parsedItems!.isNotEmpty) {
                          _urlFocusNode.unfocus();
                          _listFocusNode.requestFocus();
                          setState(() {
                            final items = _filteredItems;
                            if (items.isNotEmpty) {
                              _selectedIndices.clear();
                              _lastSelectedIndex = items.first.key;
                              _selectedIndices.add(_lastSelectedIndex);
                            }
                          });
                          if (_lastSelectedIndex != -1)
                            _scrollToIndex(_lastSelectedIndex);
                          return KeyEventResult.handled;
                        }
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                    style: GoogleFonts.firaCode(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'https://youtube.com/watch?v=...\nhttps://instagram.com/...',
                      hintStyle: GoogleFonts.firaCode(color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              _buildEngineDropdown(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IgnorePointer(
                    ignoring: hasItems,
                    child: Opacity(
                      opacity: hasItems ? 0.4 : 1.0,
                      child: ElevatedButton.icon(
                        onPressed: () => _importList(),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Import'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceBase,
                          foregroundColor: Colors.white,
                          fixedSize: const Size.fromHeight(36),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.white10),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 32,
                    width: 140,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.magenta,
                          AppColors.violet,
                          AppColors.indigo,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _analyzeUrls,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(140, 32),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              child: _JugglingBallsLoader(),
                            )
                          : Text(
                              'Fetch',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
