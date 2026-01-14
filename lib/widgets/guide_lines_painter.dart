import 'package:flutter/material.dart';

/// Custom painter that draws horizontal guide lines to show pushup position thresholds.
///
/// - Lower line: Shows where the "down" position threshold is
/// - Upper line: Shows where the "up" position threshold is
class GuideLinesPainter extends CustomPainter {
  /// Y-coordinate for the upper guide line (up position)
  final double? upperLineY;

  /// Y-coordinate for the lower guide line (down position)
  final double? lowerLineY;

  /// Whether the upper line should flash (user just crossed it)
  final bool upperLineFlash;

  /// Whether the lower line should flash (user just crossed it)
  final bool lowerLineFlash;

  /// Line color (default green)
  final Color lineColor;

  /// Flash color when crossing
  final Color flashColor;

  GuideLinesPainter({
    this.upperLineY,
    this.lowerLineY,
    this.upperLineFlash = false,
    this.lowerLineFlash = false,
    this.lineColor = Colors.green,
    this.flashColor = Colors.yellow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate line width (~2/3 of screen, centered)
    final lineWidth = size.width * 0.67;
    final startX = (size.width - lineWidth) / 2;
    final endX = startX + lineWidth;

    // Draw upper line if position is known
    if (upperLineY != null && upperLineY! > 0 && upperLineY! < size.height) {
      final upperPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = upperLineFlash ? flashColor : lineColor;

      canvas.drawLine(
        Offset(startX, upperLineY!),
        Offset(endX, upperLineY!),
        upperPaint,
      );

      // Draw small label
      _drawLabel(canvas, 'UP', Offset(endX + 8, upperLineY!), upperLineFlash);
    }

    // Draw lower line if position is known
    if (lowerLineY != null && lowerLineY! > 0 && lowerLineY! < size.height) {
      final lowerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = lowerLineFlash ? flashColor : lineColor;

      canvas.drawLine(
        Offset(startX, lowerLineY!),
        Offset(endX, lowerLineY!),
        lowerPaint,
      );

      // Draw small label
      _drawLabel(canvas, 'DOWN', Offset(endX + 8, lowerLineY!), lowerLineFlash);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset position, bool isFlashing) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isFlashing ? flashColor : lineColor,
          fontSize: 10,
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
    return oldDelegate.upperLineY != upperLineY ||
        oldDelegate.lowerLineY != lowerLineY ||
        oldDelegate.upperLineFlash != upperLineFlash ||
        oldDelegate.lowerLineFlash != lowerLineFlash;
  }
}
