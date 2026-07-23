import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_metadata_utils.dart';
import 'package:path/path.dart' as p;

class AudioPropertiesDialog extends StatefulWidget {

  const AudioPropertiesDialog({
    required this.path, super.key,
    this.testTag,
    this.testProperties,
    this.testStat,
  });
  final String path;

  /// Optional overrides for testing — bypasses FFI and filesystem calls.
  final Tag? testTag;
  final AudioProperties? testProperties;
  final FileStat? testStat;

  static Future<void> show(BuildContext context, String path) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) => AudioPropertiesDialog(path: path),
    );
  }

  @override
  State<AudioPropertiesDialog> createState() => _AudioPropertiesDialogState();
}

class _AudioPropertiesDialogState extends State<AudioPropertiesDialog> {
  bool _isLoading = true;
  Tag? _tag;
  AudioProperties? _properties;
  late FileStat _stat;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    try {
      if (widget.testStat != null ||
          widget.testTag != null ||
          widget.testProperties != null) {
        // Use injected test data — no real I/O.
        _stat = widget.testStat ?? File(widget.path).statSync();
        _tag = widget.testTag;
        _properties = widget.testProperties;
      } else {
        _stat = File(widget.path).statSync();
        _tag = await AudioMetadataUtils.readTags(widget.path);
        _properties = await AudioMetadataUtils.getProperties(widget.path);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: const Color(0xFF161616).withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.violet),
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('METADATA'),
                          _buildPropRow('Title', _tag?.title ?? 'Unknown'),
                          _buildPropRow(
                            'Artist',
                            _tag?.trackArtist ?? 'Unknown',
                          ),
                          _buildPropRow('Album', _tag?.album ?? 'Unknown'),
                          _buildPropRow('Genre', _tag?.genre ?? 'Unknown'),

                          const SizedBox(height: 20),
                          _buildSectionHeader('AUDIO FORMAT'),
                          _buildPropRow(
                            'Duration',
                            _properties?.duration ?? 'Unknown',
                          ),
                          _buildPropRow(
                            'Bitrate',
                            _properties?.bitrate ?? 'Unknown',
                          ),
                          _buildPropRow(
                            'Sample Rate',
                            _properties?.sampleRate ?? 'Unknown',
                          ),

                          const SizedBox(height: 20),
                          _buildSectionHeader('FILE SYSTEM'),
                          _buildPropRow('File Name', p.basename(widget.path)),
                          _buildPropRow(
                            'Location',
                            widget.path,
                            isSelectable: true,
                          ),
                          _buildPropRow('Size', _formatBytes(_stat.size)),
                          _buildPropRow(
                            'Added Time',
                            DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(_stat.changed),
                          ),
                          _buildPropRow(
                            'Updated Time',
                            DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(_stat.modified),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'AUDIO INFORMATION',
            style: AppTheme.labelStyle.copyWith(
              letterSpacing: 2,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.violet.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildPropRow(
    String label,
    String value, {
    bool isSelectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: isSelectable
                ? SelectableText(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(100),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Close',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
