import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class LineNumbersPainter extends CustomPainter {
  final GlobalKey editorKey;
  final TextEditingController controller;
  final TextStyle textStyle;

  LineNumbersPainter({
    required this.editorKey,
    required this.controller,
    required this.textStyle,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox? renderTextField = editorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderTextField == null) return;
    
    RenderEditable? renderEditable;
    void findRenderEditable(RenderObject element) {
      if (element is RenderEditable) {
        renderEditable = element;
        return;
      }
      element.visitChildren(findRenderEditable);
    }
    findRenderEditable(renderTextField);
    
    if (renderEditable == null) return;

    final Offset offset = renderEditable!.localToGlobal(Offset.zero, ancestor: renderTextField);
    final double dyOffset = offset.dy;

    final text = controller.text;
    final lines = text.split('\n');
    int currentOffset = 0;
    double lastDy = dyOffset;
    
    for (int i = 0; i < lines.length; i++) {
      final selection = TextSelection.collapsed(offset: currentOffset);
      final endpoints = renderEditable!.getEndpointsForSelection(selection);
      
      double dy;
      if (endpoints.isNotEmpty) {
        // endpoints[0].point.dy is the BOTTOM of the caret on that line
        // We subtract the strut height (15 * 1.5 = 22.5) to get the top Y coordinate
        dy = endpoints[0].point.dy + dyOffset - 22.5;
        lastDy = dy;
      } else {
        // If endpoints is empty (e.g. trailing empty line), guess position based on last known dy
        // Since it's an empty line, it doesn't wrap, so it's exactly 1 line height (22.5) below
        dy = lastDy + 22.5;
        lastDy = dy;
      }
      
      final textSpan = TextSpan(text: '${i + 1}', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        strutStyle: const StrutStyle(
          fontSize: 15,
          height: 1.5,
          forceStrutHeight: true,
        ),
      )..layout(maxWidth: size.width);
      
      // 16px right padding from the edge of the line number column (56px total width)
      final dx = 56.0 - textPainter.width - 16;
      textPainter.paint(canvas, Offset(dx, dy));
      
      currentOffset += lines[i].length + 1;
    }
  }

  @override
  bool shouldRepaint(covariant LineNumbersPainter oldDelegate) {
    return oldDelegate.controller != controller || oldDelegate.textStyle != textStyle;
  }
}
