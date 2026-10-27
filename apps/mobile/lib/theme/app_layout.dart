import 'package:flutter/material.dart';

/// Viewport-aware spacing and sizing (ponytail: one place, no magic numbers in widgets).
class AppLayout {
  AppLayout.of(BuildContext context)
      : size = MediaQuery.sizeOf(context),
        padding = MediaQuery.paddingOf(context),
        textScale = MediaQuery.textScalerOf(context).scale(1.0);

  final Size size;
  final EdgeInsets padding;
  final double textScale;

  bool get veryCompact => size.height < 640;
  bool get compact => size.height < 740 || size.width < 360;
  bool get expanded => size.height >= 820;

  double get _tier => veryCompact ? 0.85 : (compact ? 0.92 : 1.0);

  double gap(double base) => base * _tier;

  double font(double base) {
    final scaled = base * _tier;
    return scaled.clamp(base * 0.85, base * 1.08);
  }

  /// Height budget for the discover hero photo.
  double discoverPhotoHeight(double cardWidth) {
    final usableHeight = size.height - padding.top - padding.bottom;
    final chromeEstimate = (veryCompact ? 300.0 : compact ? 340.0 : 360.0) +
        (textScale > 1.15 ? 48.0 : 0.0);
    final fromViewport = (usableHeight - chromeEstimate).clamp(150.0, 400.0);
    final fromWidth = cardWidth * (veryCompact ? 0.95 : compact ? 1.05 : 1.15);
    final cap = usableHeight * (veryCompact ? 0.30 : compact ? 0.34 : 0.38);
    return [fromWidth, fromViewport, cap].reduce((a, b) => a < b ? a : b);
  }

  double get shellBottomInset => padding.bottom + (compact ? 76.0 : 88.0);

  EdgeInsets get screenPadding => EdgeInsets.fromLTRB(
        compact ? 14 : 16,
        0,
        compact ? 14 : 16,
        shellBottomInset,
      );
}
