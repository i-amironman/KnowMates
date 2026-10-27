import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../mock/welcome_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../widgets/ui_kit.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _WelcomeBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroWidth = math.min(constraints.maxWidth - 40, 420.0);

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, layout.gap(12), 20, layout.gap(16)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Column(
                      children: [
                        const AppWordmark(
                          centered: true,
                          size: 30,
                          brandAccentFirst: true,
                          subtitle:
                              'Exchange skills. Build brighter futures together today.',
                        ),
                        SizedBox(height: layout.gap(16)),
                        _GlobeHero(width: heroWidth),
                        SizedBox(height: layout.gap(12)),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'AI',
                                style: TextStyle(color: AppColors.magenta),
                              ),
                              TextSpan(text: ' Powered Global\nSkill Exchange'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: layout.font(34),
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: layout.gap(6)),
                        Text.rich(
                          const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Learn',
                                style: TextStyle(color: AppColors.magenta),
                              ),
                              TextSpan(text: ' from people. Grow together.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted.withValues(alpha: 0.85),
                            fontSize: layout.font(14),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: layout.gap(20)),
                        AppGradientButton(
                          keyId: const Key('get_started'),
                          label: 'Get Started',
                          onPressed: onGetStarted,
                        ),
                        if (onSignIn != null) ...[
                          SizedBox(height: layout.gap(8)),
                          Center(
                            child: AppTextLink(
                              label: 'I already have an account',
                              onTap: onSignIn!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WelcomeBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WelcomeBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A0A24),
            Color(0xFF050508),
            Color(0xFF120818),
          ],
        ).createShader(rect),
    );

    void waveBlob(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    waveBlob(Offset(size.width * 0.15, size.height * 0.12), size.width * 0.55, const Color(0x332A1040));
    waveBlob(Offset(size.width * 0.9, size.height * 0.22), size.width * 0.45, const Color(0x2A401850));
    waveBlob(Offset(size.width * 0.5, size.height * 0.88), size.width * 0.65, const Color(0x22180828));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcCaption extends StatelessWidget {
  const _ArcCaption();

  static const text =
      'Connect, learn, and exchange valuable skills through smart AI matching.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 64,
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

  /// Design wave: high at both ends and the middle, troughs at 1/4 and 3/4.
  static double waveY(double x, Size size) =>
      size.height / 2 - math.cos(4 * math.pi * x / size.width) * size.height * 0.27;

  List<TextPainter> _glyphs(double fontSize) => [
        for (final character in text.split(''))
          TextPainter(
            text: TextSpan(
              text: character,
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.9),
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout(),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    // Arc length table so glyphs keep even spacing on the steep parts.
    final arc = <double>[0];
    for (var x = 1; x <= size.width.floor(); x++) {
      final dy = waveY(x.toDouble(), size) - waveY(x - 1.0, size);
      arc.add(arc.last + math.sqrt(1 + dy * dy));
    }
    double xAt(double s) {
      var i = 1;
      while (i < arc.length - 1 && arc[i] < s) {
        i++;
      }
      final t = ((s - arc[i - 1]) / (arc[i] - arc[i - 1])).clamp(0.0, 1.0);
      return i - 1 + t;
    }

    const baseFont = 13.0;
    var glyphs = _glyphs(baseFont);
    var textWidth = glyphs.fold<double>(0, (w, g) => w + g.width);
    final fit = arc.last * 0.97 / textWidth;
    if (fit < 1) {
      glyphs = _glyphs(baseFont * fit);
      textWidth = glyphs.fold<double>(0, (w, g) => w + g.width);
    }

    var s = (arc.last - textWidth) / 2;
    for (final glyph in glyphs) {
      final cx = xAt(s + glyph.width / 2);
      final angle = math.atan2(
        waveY(cx + 0.5, size) - waveY(cx - 0.5, size),
        1,
      );
      canvas
        ..save()
        ..translate(cx, waveY(cx, size))
        ..rotate(angle);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
      s += glyph.width;
    }
  }

  @override
  bool shouldRepaint(covariant ArcCaptionPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.textScaler != textScaler;
  }
}

class _GlobeHero extends StatelessWidget {
  const _GlobeHero({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The plexus spans ~71% of the asset, so scale it to fill the
              // hero; luminance-as-alpha drops the JPG's black square.
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.3,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      1, 0, 0, 0, 0, //
                      0, 1, 0, 0, 0, //
                      0, 0, 1, 0, 0, //
                      0.8, 0.8, 0.8, 0, 0,
                    ]),
                    child: Image.asset(
                      'assets/welcome/globe_plexus.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              for (final slot in welcomeAvatarSlots)
                _AvatarBadge(slot: slot, heroWidth: width),
            ],
          ),
        ),
        const _ArcCaption(),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.slot, required this.heroWidth});

  final WelcomeAvatarSlot slot;
  final double heroWidth;

  @override
  Widget build(BuildContext context) {
    final diameter = slot.size * heroWidth;
    return Positioned(
      left: slot.align.dx * heroWidth - diameter / 2,
      top: slot.align.dy * heroWidth - diameter / 2,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: slot.pastelBackground,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(diameter * 0.05),
          child: ClipOval(
            child: Image.asset(
              slot.assetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
