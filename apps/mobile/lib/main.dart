import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const KnowMatesApp());
}

class KnowMatesApp extends StatelessWidget {
  const KnowMatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KnowMates',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: WelcomeScreen(onGetStarted: () {}),
    );
  }
}
