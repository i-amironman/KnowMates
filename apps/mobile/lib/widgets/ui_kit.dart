import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';

InputDecoration appInputDecoration({
  required String label,
  String? hint,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffix: suffix,
    labelStyle: const TextStyle(color: AppColors.muted),
    hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.7)),
    filled: true,
    fillColor: AppColors.card,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.cardEdge),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.magenta, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  );
}

class AppScreen extends StatelessWidget {
  const AppScreen({super.key, required this.body, this.appBar});

  final Widget body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      body: Stack(
        fit: StackFit.expand,
        children: [const AppAmbientGlow(), body],
      ),
    );
  }
}

class AppAmbientGlow extends StatelessWidget {
  const AppAmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _GlowBlob(
              size: 220,
              colors: [
                AppColors.magenta.withValues(alpha: 0.22),
                AppColors.bg.withValues(alpha: 0),
              ],
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            child: _GlowBlob(
              size: 180,
              colors: [
                AppColors.purple.withValues(alpha: 0.18),
                AppColors.bg.withValues(alpha: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    this.centered = false,
    this.size = 26,
    this.matesOutlined = false,
    this.pill = false,
    this.subtitle,
    this.brandAccentFirst = false,
  });

  final bool centered;
  final double size;
  final bool matesOutlined;
  final bool pill;
  final String? subtitle;

  /// Matches reference layouts: first word accent, second word white.
  final bool brandAccentFirst;

  @override
  Widget build(BuildContext context) {
    final know = Text(
      'Know',
      style: TextStyle(
        color: brandAccentFirst ? AppColors.magenta : AppColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        shadows: brandAccentFirst
            ? [
                Shadow(
                  color: AppColors.magenta.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
    );
    final mates = matesOutlined
        ? ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.magenta, AppColors.text],
            ).createShader(bounds),
            child: Text(
              'Mates',
              style: TextStyle(
                color: AppColors.text,
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          )
        : Text(
            'Mates',
            style: TextStyle(
              color: brandAccentFirst ? AppColors.text : AppColors.magenta,
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              shadows: brandAccentFirst
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [know, mates],
    );

    if (!pill && subtitle == null) {
      return centered ? Center(child: row) : row;
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: row,
              )
            : row,
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
    return centered ? Center(child: content) : content;
  }
}

class AppGradientButton extends StatelessWidget {
  const AppGradientButton({
    super.key,
    this.keyId,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final Key? keyId;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          gradient: LinearGradient(
            colors: enabled
                ? AppColors.primaryGradient
                : [
                    AppColors.orange.withValues(alpha: 0.45),
                    AppColors.pink.withValues(alpha: 0.45),
                  ],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: keyId,
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(28),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.text,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: AppColors.text, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppTextLink extends StatelessWidget {
  const AppTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showMenu = false,
    this.showDiscoverMark = false,
    this.trailing,
    this.onMenu,
    this.glassChrome = false,
  });

  final String title;
  final bool showMenu;
  final bool showDiscoverMark;
  final Widget? trailing;
  final VoidCallback? onMenu;
  final bool glassChrome;

  @override
  Size get preferredSize => Size.fromHeight(glassChrome ? 52 : 56);

  @override
  Widget build(BuildContext context) {
    if (glassChrome) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              if (showMenu)
                AppGlassIconButton(
                  icon: Icons.menu_rounded,
                  onPressed: onMenu ?? () {},
                )
              else
                const SizedBox(width: 44),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showDiscoverMark) ...[
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 26,
                              color: AppColors.text.withValues(alpha: 0.92),
                            ),
                            Positioned(
                              bottom: 5,
                              child: Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: AppColors.magenta.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox(width: 44, height: 44),
            ],
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: AppColors.bg.withValues(alpha: 0.92),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: showMenu
          ? IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.text),
              onPressed: onMenu ?? () {},
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDiscoverMark) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: AppColors.accentGradient
                      .map((c) => c.withValues(alpha: 0.9))
                      .toList(),
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        if (trailing != null)
          Padding(padding: const EdgeInsets.only(right: 12), child: trailing)
        else
          const SizedBox(width: 8),
      ],
    );
  }
}

class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: AppColors.card.withValues(alpha: 0.55),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: AppColors.text, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class AppDiscoverActionPill extends StatelessWidget {
  const AppDiscoverActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final hPad = layout.compact ? 10.0 : 14.0;
    final vPad = layout.compact ? 8.0 : 10.0;
    final iconSize = layout.compact ? 16.0 : 18.0;
    final fontSize = layout.font(13);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.compact ? 2 : 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: accent
                ? AppColors.magenta.withValues(alpha: 0.32)
                : AppColors.glass,
            child: InkWell(
              onTap: onPressed,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accent
                        ? AppColors.magenta.withValues(alpha: 0.45)
                        : AppColors.glassBorder,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: AppColors.text, size: iconSize),
                    SizedBox(width: layout.compact ? 4 : 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: fontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin,
    this.padding,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        color: gradient == null ? AppColors.card.withValues(alpha: 0.92) : null,
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A171C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2E2A31),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: AppColors.card,
      selectedColor: AppColors.magenta.withValues(alpha: 0.22),
      side: BorderSide(
        color: selected ? AppColors.magenta : AppColors.cardEdge,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.text : AppColors.muted,
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class AppCircleIconButton extends StatelessWidget {
  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.accent = false,
    this.tooltip,
    this.label,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool accent;
  final String? tooltip;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: accent
                    ? AppColors.magenta.withValues(alpha: 0.35)
                    : AppColors.glass,
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      icon,
                      color: AppColors.text,
                      size: accent ? 26 : 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class AppSetupProgress extends StatelessWidget {
  const AppSetupProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (step + 1) / total,
                minHeight: 4,
                backgroundColor: AppColors.cardEdge,
                color: AppColors.magenta,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${step + 1}/$total',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class AppGradientHighlightCard extends StatelessWidget {
  const AppGradientHighlightCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(40));
    Widget glassCircle(Widget child) => Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.text.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Center(child: child),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: AppColors.magenta.withValues(alpha: 0.35),
            ),
            gradient: RadialGradient(
              center: const Alignment(0, 1.6),
              radius: 1.6,
              colors: [
                const Color(0xFFFF3DDC).withValues(alpha: 0.75),
                const Color(0xFF2A1530),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3DDC).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              glassCircle(
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F51B5),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFFFFC857),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              glassCircle(
                const Icon(
                  Icons.north_east_rounded,
                  color: AppColors.text,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
