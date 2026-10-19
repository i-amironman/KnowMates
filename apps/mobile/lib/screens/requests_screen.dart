import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Text(
          'Learning requests',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
