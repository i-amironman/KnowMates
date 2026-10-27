import 'package:flutter/material.dart';

class WelcomeAvatarSlot {
  const WelcomeAvatarSlot({
    required this.assetPath,
    required this.pastelBackground,
    required this.align,
    required this.size,
  });

  /// Center as a fraction of the square hero box.
  final Offset align;
  /// Diameter as a fraction of the hero width.
  final double size;
  final String assetPath;
  final Color pastelBackground;
}

/// Measured from the welcome design: three large and three small badges.
const welcomeAvatarSlots = [
  WelcomeAvatarSlot(
    align: Offset(0.48, 0.15),
    size: 0.14,
    assetPath: 'assets/welcome/avatar_2.jpg',
    pastelBackground: Color(0xFFA9C4F5),
  ),
  WelcomeAvatarSlot(
    align: Offset(0.165, 0.285),
    size: 0.185,
    assetPath: 'assets/welcome/avatar_0.jpg',
    pastelBackground: Color(0xFFD9A5F5),
  ),
  WelcomeAvatarSlot(
    align: Offset(0.81, 0.395),
    size: 0.19,
    assetPath: 'assets/welcome/avatar_3.jpg',
    pastelBackground: Color(0xFFFBE3A6),
  ),
  WelcomeAvatarSlot(
    align: Offset(0.205, 0.71),
    size: 0.14,
    assetPath: 'assets/welcome/avatar_4.jpg',
    pastelBackground: Color(0xFF9EDBD8),
  ),
  WelcomeAvatarSlot(
    align: Offset(0.78, 0.71),
    size: 0.14,
    assetPath: 'assets/welcome/avatar_1.jpg',
    pastelBackground: Color(0xFFC9DFA0),
  ),
  WelcomeAvatarSlot(
    align: Offset(0.48, 0.85),
    size: 0.185,
    assetPath: 'assets/welcome/avatar_5.jpg',
    pastelBackground: Color(0xFFB9A3F5),
  ),
];
