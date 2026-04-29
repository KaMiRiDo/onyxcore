import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'item_card.dart';

class SelectionRectNotifier extends Notifier<Rect?> {
  @override
  Rect? build() => null;
  set state(Rect? value) => super.state = value;
}

final selectionRectProvider = NotifierProvider<SelectionRectNotifier, Rect?>(SelectionRectNotifier.new);

class RubberBandOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const RubberBandOverlay({required this.child, super.key});

  @override
  ConsumerState<RubberBandOverlay> createState() => _RubberBandOverlayState();
}

class _RubberBandOverlayState extends ConsumerState<RubberBandOverlay> {
  Offset? _startPoint;
  Offset? _currentPoint;
  bool _isDragging = false;
  Set<String> _initialSelection = {};

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        final isCtrl = HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.controlLeft) ||
            HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.controlRight);

        setState(() {
          _startPoint = details.localPosition;
          _currentPoint = details.localPosition;
          _isDragging = true;
          _initialSelection = isCtrl ? ref.read(selectionProvider).selectedPaths.toSet() : {};
        });
      },
      onPanUpdate: (details) {
        if (_isDragging) {
          setState(() {
            _currentPoint = details.localPosition;
          });
          if (_startPoint != null && _currentPoint != null) {
            _updateInteractiveSelection(Rect.fromPoints(_startPoint!, _currentPoint!));
          }
        }
      },
      onPanEnd: (details) {
        if (_isDragging && _startPoint != null && _currentPoint != null) {
          _updateInteractiveSelection(Rect.fromPoints(_startPoint!, _currentPoint!));
        }
        setState(() {
          _isDragging = false;
          _startPoint = null;
          _currentPoint = null;
        });
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging && _startPoint != null && _currentPoint != null)
            IgnorePointer(
              child: CustomPaint(
                painter: _SimpleSelectionPainter(
                  rect: Rect.fromPoints(_startPoint!, _currentPoint!),
                ),
                child: Container(),
              ),
            ),
        ],
      ),
    );
  }

  void _updateInteractiveSelection(Rect selectionRect) {
    final List<String> currentRectPaths = [];
    final RenderBox? overlayBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final origin = overlayBox.localToGlobal(Offset.zero);

    void visitor(Element element) {
      if (element.widget is ItemCard) {
        final renderBox = element.renderObject as RenderBox?;
        if (renderBox != null && renderBox.attached) {
          final itemPos = renderBox.localToGlobal(Offset.zero);
          final localItemRect = (itemPos - origin) & renderBox.size;
          
          if (selectionRect.overlaps(localItemRect)) {
            currentRectPaths.add((element.widget as ItemCard).item.path);
          }
        }
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    
    final combined = Set<String>.from(_initialSelection)..addAll(currentRectPaths);
    ref.read(selectionProvider.notifier).selectMultiple(combined.toList(), isCtrl: false);
  }
}

class _SimpleSelectionPainter extends CustomPainter {
  final Rect rect;
  _SimpleSelectionPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_SimpleSelectionPainter oldDelegate) => rect != oldDelegate.rect;
}
