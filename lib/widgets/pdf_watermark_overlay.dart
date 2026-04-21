import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Static diagonal watermark overlay for PDFs.
/// - Not movable
/// - Does not modify PDF bytes (overlay only)
class PdfWatermarkOverlay extends StatelessWidget {
  final String text;

  /// Opacity for the watermark text (0..1).
  final double opacity;

  /// Angle in radians (default: -45 degrees).
  final double angle;

  const PdfWatermarkOverlay({
    super.key,
    required this.text,
    this.opacity = 0.50,
    this.angle = -math.pi / 4,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PdfWatermarkPainter(
          text: text,
          opacity: opacity,
          angle: angle,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _PdfWatermarkPainter extends CustomPainter {
  final String text;
  final double opacity;
  final double angle;

  const _PdfWatermarkPainter({
    required this.text,
    required this.opacity,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.trim().isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final baseStyle = TextStyle(
      color: Colors.black.withOpacity(opacity.clamp(0.0, 1.0)),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    // Scale font size based on page diagonal for consistent look.
    final diagonal =
        math.sqrt(size.width * size.width + size.height * size.height);
    final fontSize = (diagonal / 33).clamp(7.0, 18.0);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: diagonal * 0.9);

    // Draw one centered diagonal line of text.
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PdfWatermarkPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.opacity != opacity ||
        oldDelegate.angle != angle;
  }
}
