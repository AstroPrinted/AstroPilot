import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ícono de telescopio del diseño (trazo sobre una grilla de 24 × 24).
class TelescopeIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool sparkle;
  final double strokeWidth;

  const TelescopeIcon({
    super.key,
    this.size = 24,
    this.color = ApColors.secondary,
    this.sparkle = true,
    this.strokeWidth = 1.7,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TelescopePainter(color, sparkle, strokeWidth),
      ),
    );
  }
}

class _TelescopePainter extends CustomPainter {
  final Color color;
  final bool sparkle;
  final double strokeWidth;

  _TelescopePainter(this.color, this.sparkle, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path poly(List<Offset> points, {bool close = false}) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (close) path.close();
      return path;
    }

    // Tubo.
    canvas.drawPath(
      poly(const [
        Offset(4.2, 13.6),
        Offset(16.9, 6.4),
        Offset(18.8, 9.8),
        Offset(6.1, 17.0),
      ], close: true),
      paint,
    );
    // Parasol.
    canvas.drawPath(
      poly(const [
        Offset(16.9, 6.4),
        Offset(18.5, 5.5),
        Offset(20.4, 8.9),
        Offset(18.8, 9.8),
      ]),
      paint,
    );
    // Ocular.
    canvas.drawPath(
      poly(const [
        Offset(2.7, 14.5),
        Offset(4.2, 13.6),
        Offset(6.1, 17.0),
        Offset(4.6, 17.9),
      ], close: true),
      paint,
    );
    // Trípode.
    canvas.drawLine(const Offset(11.4, 14.4), const Offset(8.6, 21), paint);
    canvas.drawLine(const Offset(11.4, 14.4), const Offset(14.4, 21), paint);
    if (sparkle) {
      canvas.drawLine(const Offset(20, 2.5), const Offset(20, 4.5), paint);
      canvas.drawLine(const Offset(19, 3.5), const Offset(21, 3.5), paint);
    }
  }

  @override
  bool shouldRepaint(_TelescopePainter old) =>
      old.color != color ||
      old.sparkle != sparkle ||
      old.strokeWidth != strokeWidth;
}

/// Logo de la app: el telescopio dentro de un cuadrado redondeado cian.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ApColors.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.29),
        border: Border.all(color: ApColors.secondary.withValues(alpha: 0.32)),
      ),
      alignment: Alignment.center,
      child: TelescopeIcon(size: size * 0.53),
    );
  }
}
