import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class DoodleBackground extends StatelessWidget {
  final Widget child;
  final AppThemeChoice theme;

  const DoodleBackground({super.key, required this.child, required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: colors.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DoodlePainter(
                  theme: theme,
                  color: colors.primary.withValues(alpha: isDark ? 0.13 : 0.09),
                  accent: colors.tertiary.withValues(
                    alpha: isDark ? 0.1 : 0.07,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final AppThemeChoice theme;
  final Color color;
  final Color accent;

  const _DoodlePainter({
    required this.theme,
    required this.color,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final soft = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final positions = [
      Offset(size.width * 0.08, size.height * 0.14),
      Offset(size.width * 0.82, size.height * 0.12),
      Offset(size.width * 0.18, size.height * 0.72),
      Offset(size.width * 0.76, size.height * 0.78),
      Offset(size.width * 0.48, size.height * 0.38),
      Offset(size.width * 0.92, size.height * 0.52),
    ];

    _drawHome(canvas, positions[0], line);
    _drawCart(canvas, positions[1], soft);
    _drawSpark(canvas, positions[2], line);
    _drawChat(canvas, positions[3], soft);
    _drawChecklist(canvas, positions[4], line);
    _drawLeaf(canvas, positions[5], soft);

    switch (theme) {
      case AppThemeChoice.halloween:
        _drawPumpkin(
          canvas,
          Offset(size.width * 0.58, size.height * 0.18),
          line,
        );
      case AppThemeChoice.goth:
        _drawDracula(
          canvas,
          Offset(size.width * 0.58, size.height * 0.18),
          line,
        );
      case AppThemeChoice.berlin:
        _drawAlexanderplatz(
          canvas,
          Offset(size.width * 0.58, size.height * 0.18),
          line,
        );
      case AppThemeChoice.light:
      case AppThemeChoice.dark:
        _drawSpark(canvas, Offset(size.width * 0.58, size.height * 0.18), soft);
    }
  }

  void _drawHome(Canvas canvas, Offset o, Paint paint) {
    final path = Path()
      ..moveTo(o.dx - 26, o.dy + 2)
      ..lineTo(o.dx, o.dy - 22)
      ..lineTo(o.dx + 26, o.dy + 2)
      ..moveTo(o.dx - 18, o.dy)
      ..lineTo(o.dx - 18, o.dy + 26)
      ..lineTo(o.dx + 18, o.dy + 26)
      ..lineTo(o.dx + 18, o.dy);
    canvas.drawPath(path, paint);
  }

  void _drawCart(Canvas canvas, Offset o, Paint paint) {
    canvas.drawLine(o.translate(-24, -16), o.translate(-18, -16), paint);
    canvas.drawLine(o.translate(-18, -16), o.translate(-10, 14), paint);
    canvas.drawLine(o.translate(-10, 14), o.translate(24, 14), paint);
    canvas.drawLine(o.translate(-14, -4), o.translate(22, -4), paint);
    canvas.drawCircle(o.translate(-6, 22), 3, paint);
    canvas.drawCircle(o.translate(18, 22), 3, paint);
  }

  void _drawSpark(Canvas canvas, Offset o, Paint paint) {
    canvas.drawLine(o.translate(0, -24), o.translate(0, 24), paint);
    canvas.drawLine(o.translate(-24, 0), o.translate(24, 0), paint);
    canvas.drawLine(o.translate(-14, -14), o.translate(14, 14), paint);
    canvas.drawLine(o.translate(14, -14), o.translate(-14, 14), paint);
  }

  void _drawChat(Canvas canvas, Offset o, Paint paint) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: 56, height: 36),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, paint);
    final tail = Path()
      ..moveTo(o.dx - 10, o.dy + 18)
      ..lineTo(o.dx - 20, o.dy + 30)
      ..lineTo(o.dx + 2, o.dy + 18);
    canvas.drawPath(tail, paint);
    canvas.drawLine(o.translate(-14, -4), o.translate(14, -4), paint);
    canvas.drawLine(o.translate(-14, 6), o.translate(4, 6), paint);
  }

  void _drawChecklist(Canvas canvas, Offset o, Paint paint) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o, width: 44, height: 58),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, paint);
    for (var i = 0; i < 3; i++) {
      final y = o.dy - 16 + (i * 16);
      canvas.drawLine(Offset(o.dx - 14, y), Offset(o.dx - 8, y + 5), paint);
      canvas.drawLine(Offset(o.dx - 8, y + 5), Offset(o.dx - 1, y - 5), paint);
      canvas.drawLine(Offset(o.dx + 8, y), Offset(o.dx + 16, y), paint);
    }
  }

  void _drawLeaf(Canvas canvas, Offset o, Paint paint) {
    final path = Path()
      ..moveTo(o.dx, o.dy + 26)
      ..cubicTo(o.dx - 28, o.dy + 6, o.dx - 22, o.dy - 18, o.dx, o.dy - 28)
      ..cubicTo(o.dx + 22, o.dy - 16, o.dx + 26, o.dy + 8, o.dx, o.dy + 26);
    canvas.drawPath(path, paint);
    canvas.drawLine(o.translate(0, 22), o.translate(0, -18), paint);
  }

  void _drawPumpkin(Canvas canvas, Offset o, Paint paint) {
    canvas.drawOval(Rect.fromCenter(center: o, width: 58, height: 42), paint);
    canvas.drawOval(Rect.fromCenter(center: o, width: 34, height: 42), paint);
    canvas.drawLine(o.translate(0, -22), o.translate(6, -34), paint);
    canvas.drawLine(o.translate(-12, -4), o.translate(-5, 3), paint);
    canvas.drawLine(o.translate(12, -4), o.translate(5, 3), paint);
    canvas.drawLine(o.translate(-12, 12), o.translate(12, 12), paint);
  }

  void _drawDracula(Canvas canvas, Offset o, Paint paint) {
    final face = Path()
      ..moveTo(o.dx - 26, o.dy - 20)
      ..lineTo(o.dx, o.dy - 32)
      ..lineTo(o.dx + 26, o.dy - 20)
      ..lineTo(o.dx + 22, o.dy + 20)
      ..lineTo(o.dx, o.dy + 34)
      ..lineTo(o.dx - 22, o.dy + 20)
      ..close();
    canvas.drawPath(face, paint);
    canvas.drawLine(o.translate(-12, -3), o.translate(-3, -3), paint);
    canvas.drawLine(o.translate(3, -3), o.translate(12, -3), paint);
    canvas.drawLine(o.translate(-6, 12), o.translate(0, 21), paint);
    canvas.drawLine(o.translate(6, 12), o.translate(0, 21), paint);
  }

  void _drawAlexanderplatz(Canvas canvas, Offset o, Paint paint) {
    canvas.drawLine(o.translate(0, -42), o.translate(0, 34), paint);
    canvas.drawCircle(o.translate(0, -12), 18, paint);
    canvas.drawLine(o.translate(-28, 8), o.translate(28, 8), paint);
    canvas.drawLine(o.translate(-10, 34), o.translate(10, 34), paint);
    canvas.drawLine(o.translate(0, -42), o.translate(8, -58), paint);
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) {
    return theme != oldDelegate.theme ||
        color != oldDelegate.color ||
        accent != oldDelegate.accent;
  }
}
