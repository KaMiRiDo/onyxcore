import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/background_panel.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';

class UnifiedSidePanel extends ConsumerStatefulWidget {
  const UnifiedSidePanel({super.key});

  @override
  ConsumerState<UnifiedSidePanel> createState() => _UnifiedSidePanelState();
}

class _UnifiedSidePanelState extends ConsumerState<UnifiedSidePanel> {
  late final FocusScopeNode _panelFocusScopeNode;

  @override
  void initState() {
    super.initState();
    _panelFocusScopeNode = FocusScopeNode()
      ..addListener(() {
        ref.read(isDownloadsPanelFocusedProvider.notifier).state =
            _panelFocusScopeNode.hasFocus;
      });
  }

  @override
  void dispose() {
    _panelFocusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDownloadsOpen = ref.watch(downloadsPanelOpenProvider);
    final isBackgroundOpen = ref.watch(backgroundPanelOpenProvider);
    final isOpen = isDownloadsOpen || isBackgroundOpen;

    final screenWidth = MediaQuery.of(context).size.width;
    final mainAreaWidth = screenWidth - 240; // Sidebar is 240px wide
    final minWidth =
        screenWidth *
        0.25; // "currently implemented width" is 0.25 of screenWidth
    final maxWidth = mainAreaWidth / 2;

    double panelWidth = ref.watch(downloadsPanelWidthProvider);
    panelWidth = panelWidth.clamp(minWidth, maxWidth);

    final isDragging = ref.watch(isDownloadsPanelDraggingProvider);

    // Keep panels alive to avoid expensive remounts on every toggle.
    // Offstage prevents layout/paint when hidden but preserves state.
    final Widget content = Stack(
      children: [
        Offstage(
          offstage: !isDownloadsOpen,
          child: const DownloadsPanel(),
        ),
        Offstage(
          offstage: !isBackgroundOpen,
          child: const BackgroundPanel(),
        ),
      ],
    );

    return AnimatedContainer(
      duration: isDragging ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutExpo,
      width: isOpen ? panelWidth : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: isOpen
            ? Border(
                left: BorderSide(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              )
            : null,
        boxShadow: isOpen
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(-6, 0),
                ),
              ]
            : null,
      ),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (!_panelFocusScopeNode.hasFocus) {
            _panelFocusScopeNode.requestFocus();
          }
        },
        child: Stack(
          children: [
            OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: panelWidth,
              maxWidth: panelWidth,
              child: FocusScope(
                node: _panelFocusScopeNode,
                autofocus: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _panelFocusScopeNode.requestFocus();
                  },
                  child: content,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width:
                  16, // make the grab area slightly wider (16px instead of 8px) for easier grabbing
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) {
                    ref.read(isDownloadsPanelDraggingProvider.notifier).state =
                        true;
                  },
                  onPanUpdate: (details) {
                    double newWidth = screenWidth - details.globalPosition.dx;
                    newWidth = newWidth.clamp(minWidth, maxWidth);
                    ref
                        .read(downloadsPanelWidthProvider.notifier)
                        .updateWidth(newWidth);
                  },
                  onPanEnd: (_) {
                    ref.read(isDownloadsPanelDraggingProvider.notifier).state =
                        false;
                  },
                  onPanCancel: () {
                    ref.read(isDownloadsPanelDraggingProvider.notifier).state =
                        false;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
