import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';

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
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _birth = TextEditingController();
  late String _timezone;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('birth'),
            controller: _birth,
            decoration: const InputDecoration(
              labelText: 'Birth date (YYYY-MM-DD)',
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Timezone'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
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
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('submit_sign_up'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
