import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.magenta,
      secondary: AppColors.orange,
      surface: AppColors.card,
      onPrimary: AppColors.text,
      onSecondary: AppColors.text,
      onSurface: AppColors.text,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: AppColors.text)),
  );
}
