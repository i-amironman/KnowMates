import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const _Wordmark(),
                      const SizedBox(height: 20),
                      const Expanded(child: _Globe()),
                      const SizedBox(height: 20),
                      const _ArcCaption(),
                      const SizedBox(height: 16),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Learn',
                              style: TextStyle(color: AppColors.magenta),
                            ),
                            TextSpan(text: ' from people.\nGrow together.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _GradientButton(onPressed: onGetStarted),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Know',
          style: TextStyle(
            color: AppColors.magenta,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Mates',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ArcCaption extends StatelessWidget {
  const _ArcCaption();

  static const text =
      'Everyone has something to teach, and something to learn.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: CustomPaint(
            key: const Key('arc_caption'),
            painter: ArcCaptionPainter(
              text: text,
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class ArcCaptionPainter extends CustomPainter {
  const ArcCaptionPainter({required this.text, required this.textScaler});

  final String text;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    const style = TextStyle(color: AppColors.muted, fontSize: 14, height: 1);
    final glyphs = [
      for (final character in text.split(''))
        TextPainter(
          text: TextSpan(text: character, style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(),
    ];
    final textWidth = glyphs.fold<double>(
      0,
      (width, glyph) => width + glyph.width,
    );
    final radius = math.max(textWidth * 2.4, size.width);
    final startAngle = -math.pi / 2 - textWidth / (2 * radius);
    final center = Offset(size.width / 2, radius + 8);
    var distance = 0.0;

    for (final glyph in glyphs) {
      final angle = startAngle + (distance + glyph.width / 2) / radius;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(angle + math.pi / 2);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
      distance += glyph.width;
    }
  }

  @override
  bool shouldRepaint(covariant ArcCaptionPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.textScaler != textScaler;
  }
}

class _Globe extends StatelessWidget {
  const _Globe();

  static const _positions = [
    Alignment(-0.78, -0.48),
    Alignment(0.02, -0.9),
    Alignment(0.78, -0.42),
    Alignment(-0.82, 0.5),
    Alignment(0.02, 0.88),
    Alignment(0.82, 0.48),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290, maxHeight: 290),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: GlobePainter()),
              ),
              for (var index = 0; index < _positions.length; index++)
                Align(
                  alignment: _positions[index],
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: index.isEven
                        ? AppColors.card
                        : AppColors.magenta,
                    foregroundColor: AppColors.text,
                    child: Text(
                      String.fromCharCode('A'.codeUnitAt(0) + index),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobePainter extends CustomPainter {
  const GlobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.34;
    final linePaint = Paint()
      ..color = AppColors.cardEdge
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, linePaint);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.05, height: radius * 2),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.82, center.dy - radius * 0.55),
      Offset(center.dx + radius * 0.82, center.dy + radius * 0.55),
      linePaint,
    );

    final dotPaint = Paint()..color = AppColors.magenta;
    for (var index = 0; index < 32; index++) {
      final angle = index * 2 * math.pi / 32;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * (radius + 9),
        1.6,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GlobePainter oldDelegate) => false;
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          gradient: LinearGradient(colors: [AppColors.orange, AppColors.pink]),
        ),
        child: TextButton(
          key: const Key('get_started'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text,
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Get Started'),
        ),
      ),
    );
  }
}
