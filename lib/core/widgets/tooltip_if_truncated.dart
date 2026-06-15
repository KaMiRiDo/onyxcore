import 'package:flutter/material.dart';

class TooltipIfTruncated extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final String? tooltipMessage;

  const TooltipIfTruncated({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);

        final isTruncated = textPainter.didExceedMaxLines;

        final textWidget = Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );

        if (isTruncated) {
          return Tooltip(
            richMessage: WidgetSpan(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  tooltipMessage ?? text,
                  style:
                      Theme.of(context).tooltipTheme.textStyle?.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w600,
                      ),
                  softWrap: true,
                ),
              ),
            ),
            waitDuration: const Duration(milliseconds: 500),
            child: textWidget,
          );
        }

        return textWidget;
      },
    );
  }
}
