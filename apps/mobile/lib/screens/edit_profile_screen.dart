import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../screens/sign_up_screen.dart' show defaultSignupTimezone, kTimezones;
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.auth,
    required this.initial,
  });

  final AuthController auth;
  final Map<String, dynamic> initial;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(
    text: widget.initial['displayName'] as String? ?? '',
  );
  late final _bio = TextEditingController(
    text: widget.initial['bio'] as String? ?? '',
  );
  late String _timezone;
  late Set<String> _languages;
  bool _saving = false;
  String? _error;

  static const _languageOptions = ['en', 'es', 'hi'];

  @override
  void initState() {
    super.initState();
    _timezone = widget.initial['timezone'] as String? ?? defaultSignupTimezone();
    final langs = widget.initial['languages'];
    _languages = langs is List ? langs.cast<String>().toSet() : {'en'};
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name is required.');
      return;
    }
    if (_languages.isEmpty) {
      setState(() => _error = 'Pick at least one language.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final resp = await widget.auth.client.patch(
      '/v1/me',
      body: {
        'displayName': name,
        'bio': _bio.text.trim(),
        'languages': _languages.toList(),
        'timezone': _timezone,
      },
    );
    if (!mounted) {
      return;
    }
    if (resp.statusCode == 200) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = apiErrorMessage(resp) ?? 'Could not save profile.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(color: AppColors.text),
            decoration: appInputDecoration(label: 'Display name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bio,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: AppColors.text),
            decoration: appInputDecoration(
              label: 'Bio',
              hint: 'Tell others what you teach and what you are learning',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _timezone,
            dropdownColor: AppColors.card,
            decoration: appInputDecoration(label: 'Timezone'),
            items: [
              for (final tz in kTimezones)
                DropdownMenuItem(value: tz, child: Text(tz)),
            ],
            onChanged: (v) => setState(() => _timezone = v ?? _timezone),
          ),
          const SizedBox(height: 20),
          const Text(
            'Languages',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final code in _languageOptions)
                FilterChip(
                  label: Text(code),
                  selected: _languages.contains(code),
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _languages.add(code);
                      } else {
                        _languages.remove(code);
                      }
                    });
                  },
                  selectedColor: AppColors.magenta.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.text,
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.pink)),
          ],
        ],
      ),
    );
  }
}
