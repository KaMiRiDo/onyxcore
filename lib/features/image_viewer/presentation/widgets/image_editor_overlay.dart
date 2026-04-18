import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum Direction { top, bottom, left, right }

class ImageEditorOverlay extends StatefulWidget {
  final String imagePath;
  final VoidCallback onCancel;
  final Function(String? newPath, bool replaced) onSave;

  const ImageEditorOverlay({
    Key? key,
    required this.imagePath,
    required this.onCancel,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ImageEditorOverlay> createState() => _ImageEditorOverlayState();
}

class _ImageEditorOverlayState extends State<ImageEditorOverlay> {
  double _rotationAngle = 0.0; // In degrees
  double _brightness = 0.0; // Range -1.0 to 1.0
  Rect _cropRect = Rect.zero;
  bool _initialized = false;
  bool _isSaving = false;
  bool _isCancelled = false;
  late ui.Image _image;
  late Size _displaySize;
  late Offset _imageOffset;
  double _scale = 1.0;
  double _originalWidth = 0;
  double _originalHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _image = frame.image;
    _originalWidth = _image.width.toDouble();
    _originalHeight = _image.height.toDouble();
    _initialized = true;
    if (mounted) setState(() {});
  }

  void _initializeCropRect(Size availableSize) {
    if (!_initialized) return;

    final double screenRatio = availableSize.width / availableSize.height;
    final double imageRatio = _image.width / _image.height;

    if (imageRatio > screenRatio) {
      // Wide image
      _displaySize = Size(availableSize.width, availableSize.width / imageRatio);
    } else {
      // Tall image
      _displaySize = Size(availableSize.height * imageRatio, availableSize.height);
    }

    _scale = _displaySize.width / _image.width;
    _imageOffset = Offset(
      (availableSize.width - _displaySize.width) / 2,
      (availableSize.height - _displaySize.height) / 2,
    );

    // Initial crop rect is the full image
    _cropRect = Rect.fromLTWH(0, 0, _displaySize.width, _displaySize.height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurry Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),

          if (!_initialized)
            const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Adjust available size to leave room for top bar and bottom controls
                const double topBarHeight = 60;
                const double bottomControlsHeight = 240;
                final Size availableSize = Size(
                  constraints.maxWidth - 60,
                  constraints.maxHeight - topBarHeight - bottomControlsHeight - 60,
                );

                if (_cropRect == Rect.zero) {
                   _initializeCropRect(availableSize);
                }

                // Global offset for image + crop area to center it horizontally and vertically
                final double verticalCenterOffset = topBarHeight + 30 + (availableSize.height - _displaySize.height) / 2;
                final Offset activeAreaOffset = Offset(_imageOffset.dx + 30, verticalCenterOffset);

                return Stack(
                  children: [
                    // Top Bar
                    _buildTopBar(),

                    // Main Area Container
                    Positioned(
                      left: activeAreaOffset.dx,
                      top: activeAreaOffset.dy,
                      width: _displaySize.width,
                      height: _displaySize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Image Display
                          Transform.rotate(
                            angle: _rotationAngle * pi / 180,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix([
                                1, 0, 0, 0, _brightness * 255,
                                0, 1, 0, 0, _brightness * 255,
                                0, 0, 1, 0, _brightness * 255,
                                0, 0, 0, 1, 0,
                              ]),
                              child: RawImage(
                                image: _image,
                                width: _displaySize.width,
                                height: _displaySize.height,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          // Crop Frame & Grid
                          _buildCropLayer(),
                        ],
                      ),
                    ),

                    // Bottom Panel
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomControls(),
                    ),

                    if (_isSaving)
                      Container(
                        color: Colors.black.withOpacity(0.92),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                              const SizedBox(height: 32),
                              Text(
                                "Applying changes...",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 48),
                              _buildPremiumCancelButton(() {
                                setState(() => _isCancelled = true);
                              }),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(height: 60),
      ),
    );
  }

  Widget _buildCropLayer() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 3x3 Grid & Border
        Positioned.fromRect(
          rect: _cropRect,
          child: _buildGridLines(),
        ),

        // Draggable Center Area (inside crop rect)
        Positioned.fromRect(
          rect: _cropRect,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final delta = details.delta;
                double newLeft = (_cropRect.left + delta.dx).clamp(0.0, _displaySize.width - _cropRect.width);
                double newTop = (_cropRect.top + delta.dy).clamp(0.0, _displaySize.height - _cropRect.height);
                _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect.width, _cropRect.height);
              });
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        // Edge Handles
        _buildEdgeHandle(Direction.top),
        _buildEdgeHandle(Direction.bottom),
        _buildEdgeHandle(Direction.left),
        _buildEdgeHandle(Direction.right),

        // Corner Handles
        _buildHandle(Alignment.topLeft),
        _buildHandle(Alignment.topRight),
        _buildHandle(Alignment.bottomLeft),
        _buildHandle(Alignment.bottomRight),
      ],
    );
  }

  Widget _buildEdgeHandle(Direction direction) {
    double left = 0, top = 0, width = 0, height = 0;
    const double hitWidth = 30.0;

    switch (direction) {
      case Direction.top:
        left = _cropRect.left + 12;
        top = _cropRect.top - hitWidth / 2;
        width = _cropRect.width - 24;
        height = hitWidth;
        break;
      case Direction.bottom:
        left = _cropRect.left + 12;
        top = _cropRect.bottom - hitWidth / 2;
        width = _cropRect.width - 24;
        height = hitWidth;
        break;
      case Direction.left:
        left = _cropRect.left - hitWidth / 2;
        top = _cropRect.top + 12;
        width = hitWidth;
        height = _cropRect.height - 24;
        break;
      case Direction.right:
        left = _cropRect.right - hitWidth / 2;
        top = _cropRect.top + 12;
        width = hitWidth;
        height = _cropRect.height - 24;
        break;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            final delta = details.delta;
            double l = _cropRect.left, t = _cropRect.top, r = _cropRect.right, b = _cropRect.bottom;
            if (direction == Direction.top) t = (t + delta.dy).clamp(0.0, b - 40);
            if (direction == Direction.bottom) b = (b + delta.dy).clamp(t + 40, _displaySize.height);
            if (direction == Direction.left) l = (l + delta.dx).clamp(0.0, r - 40);
            if (direction == Direction.right) r = (r + delta.dx).clamp(l + 40, _displaySize.width);
            _cropRect = Rect.fromLTRB(l, t, r, b);
          });
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGridLines() {
    return CustomPaint(
      painter: GridPainter(),
    );
  }

  Widget _buildHandle(Alignment alignment) {
    double x = 0;
    double y = 0;
    
    if (alignment == Alignment.topLeft) { x = _cropRect.left; y = _cropRect.top; }
    else if (alignment == Alignment.topRight) { x = _cropRect.right; y = _cropRect.top; }
    else if (alignment == Alignment.bottomLeft) { x = _cropRect.left; y = _cropRect.bottom; }
    else if (alignment == Alignment.bottomRight) { x = _cropRect.right; y = _cropRect.bottom; }

    return Positioned(
      left: x - 24,
      top: y - 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            final delta = details.delta;
            double left = _cropRect.left, top = _cropRect.top, right = _cropRect.right, bottom = _cropRect.bottom;

            if (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft) {
              left = (left + delta.dx).clamp(0.0, right - 40);
            }
            if (alignment == Alignment.topLeft || alignment == Alignment.topRight) {
              top = (top + delta.dy).clamp(0.0, bottom - 40);
            }
            if (alignment == Alignment.topRight || alignment == Alignment.bottomRight) {
              right = (right + delta.dx).clamp(left + 40, _displaySize.width);
            }
            if (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight) {
              bottom = (bottom + delta.dy).clamp(top + 40, _displaySize.height);
            }

            _cropRect = Rect.fromLTRB(left, top, right, bottom);
          });
        },
        child: Container(
          width: 48,
          height: 48,
          color: Colors.transparent,
        ),
      ),
    );
  }


  Widget _buildBottomControls() {
    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                ),
                Text(
                  "${_rotationAngle.toInt()}°",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _showSaveOptions,
                  icon: const Icon(Icons.check, color: Color(0xFF00E5FF), size: 28),
                ),
              ],
            ),
          ),
          
          // Rotation Slider
          const SizedBox(height: 5),
          _buildControlLabel(Icons.rotate_right, "Rotation"),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _rotationAngle = (_rotationAngle + details.delta.dx * 0.5).clamp(-180.0, 180.0);
              });
            },
            child: Container(
              height: 40,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: CustomPaint(
                painter: RotationSliderPainter(_rotationAngle),
              ),
            ),
          ),

          // Brightness Slider
          const SizedBox(height: 10),
          _buildControlLabel(Icons.brightness_6, "Brightness"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF00E5FF),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
                trackHeight: 2,
              ),
              child: Slider(
                value: _brightness,
                min: -1.0,
                max: 1.0,
                onChanged: (val) => setState(() => _brightness = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlLabel(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCancelButton(VoidCallback onCancel) {
    return TextButton(
      onPressed: onCancel,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF00E5FF),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
        ),
      ),
      child: Text(
        "CANCEL",
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showSaveOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Save Changes", style: TextStyle(color: Colors.white)),
        content: const Text("Confirm your selection:", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveImage(true);
            },
            child: const Text("SAVE COPY", style: TextStyle(color: Color(0xFF00E5FF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveImage(false);
            },
            child: const Text("REPLACE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
  Future<void> _saveImage(bool saveCopy) async {
    setState(() {
      _isSaving = true;
      _isCancelled = false;
    });
    try {
      final String inputPath = widget.imagePath;
      final File inputFile = File(inputPath);
      final Directory dir = inputFile.parent;
      String outputPath;
      
      if (saveCopy) {
        final String fileName = inputPath.split('/').last;
        outputPath = "${dir.path}/copy_$fileName";
        int counter = 1;
        while (await File(outputPath).exists()) {
           outputPath = "${dir.path}/copy_${counter}_$fileName";
           counter++;
        }
      } else {
        outputPath = "${dir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg";
      }

      final double realX = _cropRect.left / _scale;
      final double realY = _cropRect.top / _scale;
      final double realW = _cropRect.width / _scale;
      final double realH = _cropRect.height / _scale;

      String filter = "";
      if (_rotationAngle != 0) {
        filter += "rotate=$_rotationAngle*PI/180:bilinear=1";
      }
      if (_brightness != 0) {
        if (filter.isNotEmpty) filter += ",";
        filter += "eq=brightness=$_brightness";
      }
      if (filter.isNotEmpty) filter += ",";
      filter += "crop=${realW.toInt()}:${realH.toInt()}:${realX.toInt()}:${realY.toInt()}";

      final String cmd = 'ffmpeg -i "$inputPath" -vf "$filter" "$outputPath" -y';
      final result = await Process.run('bash', ['-c', cmd]);

      if (_isCancelled) {
        // Delete temp if it was replace mode
        if (!saveCopy && await File(outputPath).exists()) {
          await File(outputPath).delete();
        }
        return;
      }

      if (result.exitCode == 0) {
        if (!saveCopy) {
          await inputFile.delete();
          await File(outputPath).rename(inputPath);
          outputPath = inputPath;
        }
        widget.onSave(outputPath, !saveCopy);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing failed")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 3;

    // Border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..style = PaintingStyle.stroke);

    // 3x3 Grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), gridPaint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), gridPaint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), gridPaint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), gridPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


class RotationSliderPainter extends CustomPainter {
  final double angle;

  RotationSliderPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;

    const int tickCount = 40;
    final double spacing = size.width / tickCount;

    for (int i = 0; i <= tickCount; i++) {
       final double x = i * spacing;
       canvas.drawLine(Offset(x, size.height * 0.3), Offset(x, size.height * 0.7), tickPaint);
    }

    final Paint pointerPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 3;

    final double pointerX = (size.width / 2) + (angle / 180.0) * (size.width / 2);
    canvas.drawLine(Offset(pointerX, 0), Offset(pointerX, size.height), pointerPaint);
  }

  @override
  bool shouldRepaint(covariant RotationSliderPainter oldDelegate) => oldDelegate.angle != angle;
}
