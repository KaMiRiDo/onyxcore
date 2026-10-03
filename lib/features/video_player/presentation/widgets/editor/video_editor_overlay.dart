import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_segment.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_editor_provider.dart';
import 'package:onyxcore/features/video_player/services/video_editor_service.dart';
import 'package:path/path.dart' as p;

class VideoEditorOverlay extends ConsumerWidget {
  const VideoEditorOverlay({
    required this.controller, required this.sourceFile, required this.onClose, super.key,
  });

  final VideoController controller;
  final String sourceFile;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: Colors.black, // Root background
      child: Row(
        children: [
          // Left side: Header + Video + Timeline
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildHeader(context, ref),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Video(
                          controller: controller,
                          controls: (state) => const SizedBox.shrink(),
                        ),
                      ),
                      // Plus Button for Segments
                      _buildAddSegmentButton(context, ref),
                    ],
                  ),
                ),
                // Timeline Bottom Area
                _buildTimelineArea(context, ref),
              ],
            ),
          ),
          // Right side: Sidebar taking full height
          Container(
            width: 380,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark background for sidebar
              border: Border(left: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: _SidebarView(sourceFile: sourceFile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final fileName = p.basename(sourceFile);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: onClose,
              tooltip: 'Close Editor',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Buttons removed from header, moved to sidebar
        ],
      ),
    );
  }

  Widget _buildAddSegmentButton(BuildContext context, WidgetRef ref) {
    final pendingStart = ref.watch(videoEditorProvider.select((s) => s.pendingSegmentStart));
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton(
        heroTag: 'add_segment',
        backgroundColor: pendingStart == null 
            ? Theme.of(context).colorScheme.primary 
            : Colors.amber,
        foregroundColor: Colors.white,
        onPressed: () {
          final position = controller.player.state.position;
          final duration = controller.player.state.duration;
          ref.read(videoEditorProvider.notifier).markTimestamp(position, duration);
        },
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  Widget _buildTimelineArea(BuildContext context, WidgetRef ref) {
    final segments = ref.watch(videoEditorProvider.select((s) => s.segments));
    
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<Duration>(
              stream: controller.player.stream.position,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = controller.player.state.duration;
                
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (duration.inMilliseconds == 0) return;
                        final newPos = Duration(
                          milliseconds: (details.localPosition.dx / width * duration.inMilliseconds).clamp(0, duration.inMilliseconds).toInt(),
                        );
                        controller.player.seek(newPos);
                      },
                      onPanUpdate: (details) {
                        if (duration.inMilliseconds == 0) return;
                        final newPos = Duration(
                          milliseconds: (details.localPosition.dx / width * duration.inMilliseconds).clamp(0, duration.inMilliseconds).toInt(),
                        );
                        controller.player.seek(newPos);
                      },
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Base Timeline Track
                          Container(
                            height: 48,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Segments Overlay
                          ...segments.map((seg) {
                            if (duration.inMilliseconds == 0) return const SizedBox.shrink();
                            
                            final startRatio = seg.start.inMilliseconds / duration.inMilliseconds;
                            final endRatio = seg.end.inMilliseconds / duration.inMilliseconds;
                            
                            final left = startRatio * width;
                            final segWidth = (endRatio - startRatio) * width;
                            
                            return Positioned(
                              left: left,
                              width: segWidth,
                              height: 52, // slightly taller than track
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  border: Border.all(color: Colors.white70, width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                          // Playhead
                          if (duration.inMilliseconds > 0)
                            Positioned(
                              left: (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) * width,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 3,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Time Labels
          StreamBuilder<Duration>(
            stream: controller.player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = controller.player.state.duration;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SidebarView extends ConsumerStatefulWidget {
  const _SidebarView({required this.sourceFile});
  final String sourceFile;

  @override
  ConsumerState<_SidebarView> createState() => _SidebarViewState();
}

class _SidebarViewState extends ConsumerState<_SidebarView> {
  final ScrollController _scrollController = ScrollController();
  int _prevCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onTrim(BuildContext context, WidgetRef ref, List<VideoSegment> segments, String sourceFile) {
    ref.read(videoEditorServiceProvider).trimAndMerge(
          segments,
          sourceFile,
        );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing started in background...')),
    );
  }

  void _onExtract(BuildContext context, WidgetRef ref, List<VideoSegment> segments, String sourceFile) {
    final dir = p.dirname(sourceFile);
    final name = p.basenameWithoutExtension(sourceFile);
    final outputDir = p.join(dir, '${name}_frames');
    Directory(outputDir).createSync(recursive: true);
    
    ref.read(videoEditorServiceProvider).extractFrames(
          segments,
          sourceFile,
        );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Extraction started in background...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segments = ref.watch(videoEditorProvider.select((s) => s.segments));
    
    // Auto scroll when new segment is added
    if (segments.length > _prevCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _prevCount = segments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: const Text(
            'Segments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: segments.isEmpty
              ? const Center(
                  child: Text(
                    'No segments added',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: segments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final seg = segments[index];
                    return _SegmentTile(segment: seg, index: index);
                  },
                ),
        ),
        // Action Buttons at bottom center
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.cut, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Trim & Merge',
                  onPressed: segments.isEmpty ? null : () => _onTrim(context, ref, segments, widget.sourceFile),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.collections, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Extract Frames',
                  onPressed: segments.isEmpty ? null : () => _onExtract(context, ref, segments, widget.sourceFile),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentTile extends ConsumerStatefulWidget {
  const _SegmentTile({required this.segment, required this.index});
  final VideoSegment segment;
  final int index;

  @override
  ConsumerState<_SegmentTile> createState() => _SegmentTileState();
}

class _SegmentTileState extends ConsumerState<_SegmentTile> {
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  final FocusNode _startFocus = FocusNode();
  final FocusNode _endFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(text: _formatDuration(widget.segment.start));
    _endCtrl = TextEditingController(text: _formatDuration(widget.segment.end));

    _startFocus.addListener(() {
      if (!_startFocus.hasFocus) _submitStart(_startCtrl.text);
    });
    _endFocus.addListener(() {
      if (!_endFocus.hasFocus) _submitEnd(_endCtrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant _SegmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment.start != widget.segment.start && !_startFocus.hasFocus) {
      _startCtrl.text = _formatDuration(widget.segment.start);
    }
    if (oldWidget.segment.end != widget.segment.end && !_endFocus.hasFocus) {
      _endCtrl.text = _formatDuration(widget.segment.end);
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  void _submitStart(String val) {
    final parsed = _parseDuration(val);
    if (parsed != null && parsed < widget.segment.end) {
      ref.read(videoEditorProvider.notifier).updateSegment(widget.segment.id, widget.segment.copyWith(start: parsed));
    } else {
      _startCtrl.text = _formatDuration(widget.segment.start);
    }
  }

  void _submitEnd(String val) {
    final parsed = _parseDuration(val);
    if (parsed != null && parsed > widget.segment.start) {
      ref.read(videoEditorProvider.notifier).updateSegment(widget.segment.id, widget.segment.copyWith(end: parsed));
    } else {
      _endCtrl.text = _formatDuration(widget.segment.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Range Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _startCtrl,
                      focusNode: _startFocus,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true, 
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _submitStart,
                    ),
                  ),
                  const Icon(Icons.more_horiz, size: 20, color: Colors.white54),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _endCtrl,
                      focusNode: _endFocus,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true, 
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _submitEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Actions Row
              Row(
                children: [
                  // Speed Dropdown
                  DropdownButton<double>(
                    value: widget.segment.speed,
                    items: [0.25, 0.5, 1.0, 1.25, 1.5, 2.0]
                        .map((s) => DropdownMenuItem(value: s, child: Text('${s}x', style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(videoEditorProvider.notifier).updateSegment(widget.segment.id, widget.segment.copyWith(speed: val));
                      }
                    },
                    underline: const SizedBox(),
                    dropdownColor: Colors.grey.shade900,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  // Mute Button aligned next to Speed
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      icon: Icon(widget.segment.isMuted ? Icons.volume_off : Icons.volume_up, size: 18, color: Theme.of(context).colorScheme.primary),
                      onPressed: () => ref.read(videoEditorProvider.notifier).toggleMute(widget.segment.id),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const Spacer(),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    onPressed: () => ref.read(videoEditorProvider.notifier).deleteSegment(widget.segment.id),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Number badge top left
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${widget.index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

Duration? _parseDuration(String s) {
  try {
    final parts = s.split(':');
    if (parts.length == 4) {
      return Duration(
        hours: int.parse(parts[0]),
        minutes: int.parse(parts[1]),
        seconds: int.parse(parts[2]),
        milliseconds: int.parse(parts[3]),
      );
    }
  } catch (e) {
    return null;
  }
  return null;
}

String _formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
  return '$h:$m:$s:$ms';
}
