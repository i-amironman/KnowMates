import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSubmit});

  final Future<String?> Function({required String email, required String password})
  onSubmit;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    setState(() => _busy = true);
    final err = await widget.onSubmit(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: BackButton(color: AppColors.muted.withValues(alpha: 0.9)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          const AppWordmark(centered: true, size: 26),
          const SizedBox(height: 28),
          const Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to continue learning with your KnowMates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.text),
            decoration: appInputDecoration(label: 'Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            style: const TextStyle(color: AppColors.text),
            decoration: appInputDecoration(label: 'Password'),
          ),
          const SizedBox(height: 28),
          AppGradientButton(
            label: 'Sign in',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.pink),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: AppTextLink(
              label: 'New here? Create an account',
              onTap: () => context.push('/sign-up'),
            ),
          ),
        ],
      ),
    );
  }
}
