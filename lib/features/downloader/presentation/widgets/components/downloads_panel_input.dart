part of '../downloads_panel.dart';

extension DownloadsPanelInputView on _MediaDownloaderPanelState {
  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
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
          Row(
            children: [
              _buildEngineDropdown(),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 32,
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
                      fixedSize: const Size.fromHeight(32),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            'Fetch / Analyse',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
