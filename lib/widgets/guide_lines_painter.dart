import 'package:flutter/material.dart';
import 'guide_lines_overlay.dart';

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

  /// Display mode for labels
  final GuideLineDisplayMode displayMode;

  GuideLinesPainter({
    this.upperLineY,
    this.lowerLineY,
    this.upperLineFlash = false,
    this.lowerLineFlash = false,
    this.lineColor = Colors.green,
    this.flashColor = Colors.yellow,
    this.displayMode = GuideLineDisplayMode.targetPositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate line width (~2/3 of screen, centered)
    final lineWidth = size.width * 0.67;
    final startX = (size.width - lineWidth) / 2;
    final endX = startX + lineWidth;

    // Get labels based on display mode
    final upperLabel = displayMode == GuideLineDisplayMode.targetPositions
        ? 'UP'
        : 'UP (160°)';
    final lowerLabel = displayMode == GuideLineDisplayMode.targetPositions
        ? 'DOWN'
        : 'DOWN (90°)';

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

      // Draw small arrows if in target mode
      if (displayMode == GuideLineDisplayMode.targetPositions) {
        _drawArrow(canvas, Offset(startX - 8, upperLineY!), true, upperLineFlash);
        _drawArrow(canvas, Offset(endX + 8, upperLineY!), false, upperLineFlash);
      }

      // Draw label
      _drawLabel(canvas, upperLabel, Offset(endX + 12, upperLineY!), upperLineFlash);
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

      // Draw small arrows if in target mode
      if (displayMode == GuideLineDisplayMode.targetPositions) {
        _drawArrow(canvas, Offset(startX - 8, lowerLineY!), true, lowerLineFlash);
        _drawArrow(canvas, Offset(endX + 8, lowerLineY!), false, lowerLineFlash);
      }

      // Draw label
      _drawLabel(canvas, lowerLabel, Offset(endX + 12, lowerLineY!), lowerLineFlash);
    }
  }

  void _drawArrow(Canvas canvas, Offset position, bool pointRight, bool isFlashing) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isFlashing ? flashColor : lineColor;

    final path = Path();
    if (pointRight) {
      path.moveTo(position.dx, position.dy);
      path.lineTo(position.dx - 6, position.dy - 4);
      path.lineTo(position.dx - 6, position.dy + 4);
    } else {
      path.moveTo(position.dx, position.dy);
      path.lineTo(position.dx + 6, position.dy - 4);
      path.lineTo(position.dx + 6, position.dy + 4);
    }
    path.close();
    canvas.drawPath(path, paint);
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
    return oldDelegate.upperLineY != upperLineY ||
        oldDelegate.lowerLineY != lowerLineY ||
        oldDelegate.upperLineFlash != upperLineFlash ||
        oldDelegate.lowerLineFlash != lowerLineFlash ||
        oldDelegate.displayMode != displayMode;
  }
}
