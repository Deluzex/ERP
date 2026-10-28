import 'package:flutter/material.dart';

/// Stock In custom vector icon matching the design system
/// (Tray at bottom with downward arrow pointing into it)
class StockInIcon extends StatelessWidget {
  final double size;
  final Color color;

  const StockInIcon({
    super.key,
    this.size = 20,
    this.color = const Color(0xFF16A34A),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StockInPainter(color: color),
    );
  }
}

class _StockInPainter extends CustomPainter {
  final Color color;

  const _StockInPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Open tray at bottom
    final trayPath = Path()
      ..moveTo(w * 0.16, h * 0.60)
      ..lineTo(w * 0.16, h * 0.82)
      ..quadraticBezierTo(w * 0.16, h * 0.90, w * 0.26, h * 0.90)
      ..lineTo(w * 0.74, h * 0.90)
      ..quadraticBezierTo(w * 0.84, h * 0.90, w * 0.84, h * 0.82)
      ..lineTo(w * 0.84, h * 0.60);
    canvas.drawPath(trayPath, paint);

    // Downward arrow stem
    canvas.drawLine(
      Offset(w * 0.50, h * 0.22),
      Offset(w * 0.50, h * 0.70),
      paint,
    );

    // Arrow chevron head pointing down
    final arrowHead = Path()
      ..moveTo(w * 0.32, h * 0.52)
      ..lineTo(w * 0.50, h * 0.70)
      ..lineTo(w * 0.68, h * 0.52);
    canvas.drawPath(arrowHead, paint);
  }

  @override
  bool shouldRepaint(covariant _StockInPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Stock Out custom vector icon matching the design system
/// (Inverted tray at top with upward arrow pointing out)
class StockOutIcon extends StatelessWidget {
  final double size;
  final Color color;

  const StockOutIcon({
    super.key,
    this.size = 20,
    this.color = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StockOutPainter(color: color),
    );
  }
}

class _StockOutPainter extends CustomPainter {
  final Color color;

  const _StockOutPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Inverted open tray at top
    final trayPath = Path()
      ..moveTo(w * 0.16, h * 0.40)
      ..lineTo(w * 0.16, h * 0.18)
      ..quadraticBezierTo(w * 0.16, h * 0.10, w * 0.26, h * 0.10)
      ..lineTo(w * 0.74, h * 0.10)
      ..quadraticBezierTo(w * 0.84, h * 0.10, w * 0.84, h * 0.18)
      ..lineTo(w * 0.84, h * 0.40);
    canvas.drawPath(trayPath, paint);

    // Upward arrow stem
    canvas.drawLine(
      Offset(w * 0.50, h * 0.78),
      Offset(w * 0.50, h * 0.30),
      paint,
    );

    // Arrow chevron head pointing up
    final arrowHead = Path()
      ..moveTo(w * 0.32, h * 0.48)
      ..lineTo(w * 0.50, h * 0.30)
      ..lineTo(w * 0.68, h * 0.48);
    canvas.drawPath(arrowHead, paint);
  }

  @override
  bool shouldRepaint(covariant _StockOutPainter oldDelegate) =>
      oldDelegate.color != color;
}

