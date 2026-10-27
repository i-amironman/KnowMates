import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rotating particle sphere with a pulsing rim and orbiting sparks,
/// so the AI orb reads as "working".
class HomeOrb extends StatefulWidget {
  const HomeOrb({super.key, this.size = 180});

  final double size;

  @override
  State<HomeOrb> createState() => _HomeOrbState();
}

class _HomeOrbState extends State<HomeOrb> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI assistant',
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _OrbPainter(_controller)),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static const _rim = Color(0xFFFF3DDC);
  static const _core = Color(0xFFE040FB);

  // Fibonacci sphere: evenly spread unit vectors.
  static final List<(double, double, double)> _points = () {
    const n = 1100;
    final golden = math.pi * (3 - math.sqrt(5));
    return [
      for (var i = 0; i < n; i++)
        () {
          final y = 1 - (i / (n - 1)) * 2;
          final r = math.sqrt(1 - y * y);
          final a = golden * i;
          return (math.cos(a) * r, y, math.sin(a) * r);
        }(),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final center = size.center(Offset.zero);
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 6);
    final radius = size.width * 0.40 * (1 + pulse * 0.015);

    // Halo.
    canvas.drawCircle(
      center,
      radius * 1.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _rim.withValues(alpha: 0),
            _rim.withValues(alpha: 0.18 + pulse * 0.10),
            _rim.withValues(alpha: 0),
          ],
          stops: const [0.62, 0.75, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.35)),
    );

    // Dark core so the sphere reads as a shell.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF14061A), const Color(0xFF2A0A30)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Blurred rim glow.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = _rim.withValues(alpha: 0.6 + pulse * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFFFA6F0).withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Rotating particles; points near the limb are brightest.
    final spin = t * math.pi * 2;
    final cosA = math.cos(spin), sinA = math.sin(spin);
    const tilt = 0.35;
    final cosT = math.cos(tilt), sinT = math.sin(tilt);
    final dot = Paint();
    for (final (x, y, z) in _points) {
      final x1 = x * cosA + z * sinA;
      final z1 = -x * sinA + z * cosA;
      final y2 = y * cosT - z1 * sinT;
      final z2 = y * sinT + z1 * cosT;
      final limb = 1 - z2.abs();
      final alpha = z2 > 0
          ? 0.08 + math.pow(limb, 4) * 0.9
          : 0.03 + math.pow(limb, 6) * 0.6;
      dot.color = (limb > 0.85 ? Colors.white : _core).withValues(alpha: alpha);
      canvas.drawCircle(
        center + Offset(x1, y2) * radius,
        0.6 + limb * 0.9,
        dot,
      );
    }

    // Orbiting "thinking" sparks.
    final spark = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    for (var i = 0; i < 3; i++) {
      final a = spin * (2 + i) + i * 2.1;
      final orbit = radius * (1.06 + i * 0.05);
      final p =
          center + Offset(math.cos(a) * orbit, math.sin(a) * orbit * 0.92);
      spark.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(p, 2.2, spark);
      spark.color = _rim.withValues(alpha: 0.6);
      canvas.drawCircle(p, 5, spark);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => false;
}
