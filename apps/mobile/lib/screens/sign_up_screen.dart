import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

const kTimezones = [
  'Asia/Kolkata',
  'Etc/UTC',
  'America/New_York',
  'America/Los_Angeles',
  'Europe/London',
  'Europe/Paris',
  'Asia/Tokyo',
  'Australia/Sydney',
];

String defaultSignupTimezone() {
  if (DateTime.now().timeZoneOffset == const Duration(hours: 5, minutes: 30)) {
    return 'Asia/Kolkata';
  }
  return 'Etc/UTC';
}

bool isAtLeast18(String birthDate) {
  final birth = DateTime.tryParse(birthDate);
  if (birth == null) {
    return false;
  }
  final today = DateTime.now();
  var age = today.year - birth.year;
  if (today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day)) {
    age--;
  }
  return age >= 18;
}

typedef SignUpSubmit = dynamic Function(SignUpInput input);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.onSubmit});

  final SignUpSubmit onSubmit;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _birth = TextEditingController();
  late String _timezone;
  String? _gender;
  String? _localError;
  String? _apiError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timezone = defaultSignupTimezone();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _birth.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _localError = null;
      _apiError = null;
    });
    if (_displayName.text.trim().isEmpty) {
      setState(() => _localError = 'Enter a display name.');
      return;
    }
    if (_gender != 'male' && _gender != 'female') {
      setState(() => _localError = 'Select your gender for your avatar.');
      return;
    }
    final birth = _birth.text.trim();
    if (!isAtLeast18(birth)) {
      setState(() => _localError = 'You need to be 18 or older.');
      return;
    }
    if (_password.text.length < 10) {
      setState(
        () => _localError = 'Password must be at least 10 characters.',
      );
      return;
    }
    setState(() => _busy = true);
    final input = SignUpInput(
      displayName: _displayName.text.trim(),
      gender: _gender!,
      email: _email.text,
      password: _password.text,
      birthDate: birth,
      timezone: _timezone,
    );
    final result = widget.onSubmit(input);
    final String? err;
    if (result is Future) {
      err = await result as String?;
    } else {
      err = result as String?;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _apiError = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _localError ?? _apiError;
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
            'Join KnowMates',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your account and start learning from real people.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 32),
          TextField(
            key: const Key('display_name'),
            controller: _displayName,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.text),
            decoration: appInputDecoration(label: 'Display name'),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gender',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppFilterChip(
                label: 'Male',
                selected: _gender == 'male',
                onSelected: (on) {
                  setState(() => _gender = on ? 'male' : null);
                },
              ),
              AppFilterChip(
                label: 'Female',
                selected: _gender == 'female',
                onSelected: (on) {
                  setState(() => _gender = on ? 'female' : null);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          TextField(
            key: const Key('birth'),
            controller: _birth,
            style: const TextStyle(color: AppColors.text),
            decoration: appInputDecoration(
              label: 'Birth date (YYYY-MM-DD)',
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: appInputDecoration(label: 'Timezone'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: AppColors.card,
                value: _timezone,
                items: [
                  for (final tz in kTimezones)
                    DropdownMenuItem(value: tz, child: Text(tz)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _timezone = v);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          AppGradientButton(
            keyId: const Key('submit_sign_up'),
            label: 'Create account',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.pink),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: AppTextLink(
              label: 'Already have an account? Sign in',
              onTap: () => context.push('/sign-in'),
            ),
          ),
        ],
      ),
    );
  }
}
