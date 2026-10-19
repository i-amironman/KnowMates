import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class HomeOrb extends StatelessWidget {
  const HomeOrb({super.key});

  static const size = 180.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OrbPainter()),
    );
  }
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final gradient = RadialGradient(
      colors: [
        AppColors.pink.withValues(alpha: 0.85),
        AppColors.magenta.withValues(alpha: 0.35),
        AppColors.bg.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    const dotCount = 40;
    final dotPaint = Paint()..color = AppColors.text.withValues(alpha: 0.75);
    for (var i = 0; i < dotCount; i++) {
      final angle = (i / dotCount) * 2 * math.pi;
      final x = center.dx + math.cos(angle) * radius * 0.72;
      final y = center.dy + math.sin(angle) * radius * 0.72;
      canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
