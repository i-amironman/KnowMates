import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import 'wallet_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthController auth;

  Future<void> _deleteAccount(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes your profile, chat messages, and login. Type DELETE to confirm.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Confirmation'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.pink),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim() == 'DELETE'),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true || !context.mounted) {
      return;
    }
    final resp = await auth.client.delete('/v1/me');
    if (!context.mounted) {
      return;
    }
    if (resp.statusCode == 204) {
      await auth.signOut();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(resp) ?? 'Could not delete account.')),
    );
  }

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
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.pink),
            title: const Text('Delete account', style: TextStyle(color: AppColors.pink)),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}
