import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import 'wallet_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.magenta),
            title: const Text('Time wallet', style: TextStyle(color: AppColors.text)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WalletScreen(auth: auth),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Profile editing lands in a later task.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
