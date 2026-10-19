import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Text(
          'Sessions',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
