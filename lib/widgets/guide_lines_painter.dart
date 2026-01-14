import 'package:flutter/material.dart';

/// Custom painter that draws a single horizontal guide line for the pushup
/// down position target.
class GuideLinesPainter extends CustomPainter {
  /// Y-coordinate for the guide line
  final double? lineY;

  /// Whether the line should flash (user just crossed it)
  final bool lineFlash;

  /// Line color (default green)
  final Color lineColor;

  /// Flash color when crossing
  final Color flashColor;

  GuideLinesPainter({
    this.lineY,
    this.lineFlash = false,
    this.lineColor = Colors.green,
    this.flashColor = Colors.yellow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lineY == null || lineY! <= 0 || lineY! >= size.height) return;

    // Calculate line width (~2/3 of screen, centered)
    final lineWidth = size.width * 0.67;
    final startX = (size.width - lineWidth) / 2;
    final endX = startX + lineWidth;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = lineFlash ? flashColor : lineColor;

    canvas.drawLine(
      Offset(startX, lineY!),
      Offset(endX, lineY!),
      paint,
    );

    // Draw label
    _drawLabel(canvas, 'DOWN', Offset(endX + 12, lineY!), lineFlash);
  }

  void _drawLabel(Canvas canvas, String text, Offset position, bool isFlashing) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isFlashing ? flashColor : lineColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx, position.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(GuideLinesPainter oldDelegate) {
    return oldDelegate.lineY != lineY || oldDelegate.lineFlash != lineFlash;
  }
}
