import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/menu_tooltip.dart';

class TrackSelectorMenu extends StatelessWidget {
  final String title;
  final List<VideoTrack> videoTracks;
  final List<AudioTrack> audioTracks;
  final List<SubtitleTrack> subtitleTracks;
  final dynamic selectedTrack;
  final void Function(dynamic) onTrackSelected;
  final VoidCallback? onLoadExternal;

  const TrackSelectorMenu({
    required this.title,
    this.videoTracks = const [],
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    required this.selectedTrack,
    required this.onTrackSelected,
    this.onLoadExternal,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: 280,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26).withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      if (onLoadExternal != null) ...[
                        _buildLoadExternalButton(),
                        const Divider(color: Colors.white10, height: 16),
                      ],
                      ..._buildItems(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.manrope(
          color: Colors.white30,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLoadExternalButton() {
    return InkWell(
      onTap: onLoadExternal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.violet,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Load External Subtitle',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItems() {
    final List<dynamic> tracks = [];
    if (audioTracks.isNotEmpty) tracks.addAll(audioTracks);
    if (subtitleTracks.isNotEmpty) tracks.addAll(subtitleTracks);
    if (videoTracks.isNotEmpty) tracks.addAll(videoTracks);

    return tracks.map((track) {
      final isSelected = _isSameTrack(track, selectedTrack);
      final label = _getTrackLabel(track);

      return MenuTooltip(
        message: label,
        child: InkWell(
          onTap: () => onTrackSelected(track),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                _buildRadioButton(isSelected),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRadioButton(bool isSelected) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.white24,
          width: 1.5,
        ),
        gradient: isSelected ? AppTheme.primaryGradient : null,
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  String _getTrackLabel(dynamic track) {
    if (track is AudioTrack) {
      if (track == AudioTrack.auto()) return 'Auto';
      if (track == AudioTrack.no()) return 'None';
      return track.title ?? track.language ?? 'Audio Stream ${track.id}';
    }
    if (track is SubtitleTrack) {
      if (track == SubtitleTrack.auto()) return 'Auto';
      if (track == SubtitleTrack.no()) return 'None';
      return track.title ?? track.language ?? 'Subtitle Stream ${track.id}';
    }
    return 'Unknown Track';
  }

  bool _isSameTrack(dynamic a, dynamic b) {
    if (a.runtimeType != b.runtimeType) return false;
    if (a is AudioTrack && b is AudioTrack) return a.id == b.id;
    if (a is SubtitleTrack && b is SubtitleTrack) return a.id == b.id;
    return false;
  }
}
