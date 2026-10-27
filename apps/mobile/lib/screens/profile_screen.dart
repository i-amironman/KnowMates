import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_prefs.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import 'edit_profile_screen.dart';
import 'wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    this.onOpenTab,
  });

  final AuthController auth;
  final void Function(int shellTabIndex)? onOpenTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _prefs = ProfilePrefs();
  Map<String, dynamic>? _me;
  bool _loading = true;
  bool _push = true;
  bool _email = true;
  bool _sessionReminders = true;
  bool _chatAlerts = true;
  bool _discoverable = true;
  bool _showOnline = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await widget.auth.client.get('/v1/me');
    if (resp.statusCode == 200) {
      _me = jsonDecode(resp.body) as Map<String, dynamic>;
    }
    _push = await _prefs.pushEnabled();
    _email = await _prefs.emailUpdatesEnabled();
    _sessionReminders = await _prefs.sessionRemindersEnabled();
    _chatAlerts = await _prefs.chatAlertsEnabled();
    _discoverable = await _prefs.discoverable();
    _showOnline = await _prefs.showOnlineStatus();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    if (_me == null) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfileScreen(auth: widget.auth, initial: _me!),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deleteAccount() async {
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
              'This removes your profile, messages, and login. Type DELETE to confirm.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppColors.text),
              decoration: appInputDecoration(label: 'Confirmation'),
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
    if (ok != true || !mounted) {
      return;
    }
    final resp = await widget.auth.client.delete('/v1/me');
    if (!mounted) {
      return;
    }
    if (resp.statusCode == 204) {
      await widget.auth.signOut();
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
      appBar: const AppTopBar(title: 'Profile'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.magenta,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  if (_me != null) ...[
                    _ProfileHeader(me: _me!, onEdit: _openEdit),
                    const SizedBox(height: 20),
                    _SkillsSection(me: _me!),
                    const SizedBox(height: 24),
                  ],
                  _sectionTitle('Activity'),
                  _navTile(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.magenta,
                    title: 'Time wallet',
                    subtitle: 'Balance, holds, and session credits',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WalletScreen(auth: widget.auth),
                      ),
                    ),
                  ),
                  _navTile(
                    icon: Icons.favorite_outline,
                    title: 'Session requests',
                    subtitle: 'Incoming and sent learning requests',
                    onTap: () => widget.onOpenTab?.call(1),
                  ),
                  _navTile(
                    icon: Icons.school_outlined,
                    title: 'My sessions',
                    subtitle: 'Upcoming and completed sessions',
                    onTap: () => widget.onOpenTab?.call(3),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Notifications'),
                  _switchTile(
                    title: 'Push notifications',
                    subtitle: 'Session requests, accepts, and reminders',
                    value: _push,
                    onChanged: (v) async {
                      await _prefs.setPush(v);
                      setState(() => _push = v);
                    },
                  ),
                  _switchTile(
                    title: 'Email updates',
                    subtitle: 'Account and verification emails',
                    value: _email,
                    onChanged: (v) async {
                      await _prefs.setEmailUpdates(v);
                      setState(() => _email = v);
                    },
                  ),
                  _switchTile(
                    title: 'Session reminders',
                    subtitle: 'Before scheduled skill exchanges',
                    value: _sessionReminders,
                    onChanged: (v) async {
                      await _prefs.setSessionReminders(v);
                      setState(() => _sessionReminders = v);
                    },
                  ),
                  _switchTile(
                    title: 'Encrypted chat alerts',
                    subtitle: 'New messages in secure chats',
                    value: _chatAlerts,
                    onChanged: (v) async {
                      await _prefs.setChatAlerts(v);
                      setState(() => _chatAlerts = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Privacy & safety'),
                  _switchTile(
                    title: 'Discoverable profile',
                    subtitle: 'Show me in Discover for my learn skills',
                    value: _discoverable,
                    onChanged: (v) async {
                      await _prefs.setDiscoverable(v);
                      setState(() => _discoverable = v);
                    },
                  ),
                  _switchTile(
                    title: 'Show online status',
                    subtitle: 'Let matches see when you are active',
                    value: _showOnline,
                    onChanged: (v) async {
                      await _prefs.setShowOnlineStatus(v);
                      setState(() => _showOnline = v);
                    },
                  ),
                  _navTile(
                    icon: Icons.block_outlined,
                    title: 'Blocked accounts',
                    subtitle: 'Manage people you have blocked',
                    onTap: () => _showBlockedInfo(context),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Account'),
                  if (_me != null)
                    _infoTile(
                      icon: Icons.mail_outline,
                      title: 'Email',
                      value: _me!['email'] as String? ?? '',
                    ),
                  _navTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit profile',
                    subtitle: 'Name, bio, languages, timezone',
                    onTap: _openEdit,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Support & about'),
                  _navTile(
                    icon: Icons.help_outline,
                    title: 'Help center',
                    subtitle: 'How KnowMates works',
                    onTap: () => _showHelp(context),
                  ),
                  _navTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy policy',
                    onTap: () => _openPrivacy(context),
                  ),
                  _navTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of use',
                    onTap: () => _showTerms(context),
                  ),
                  _infoTile(
                    icon: Icons.info_outline,
                    title: 'App version',
                    value: '1.0.0',
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Session'),
                  OutlinedButton.icon(
                    onPressed: () async => widget.auth.signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.cardEdge),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppGlassCard(
                    onTap: _deleteAccount,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.pink.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.pink.withValues(alpha: 0.45)),
                          ),
                          child: const Icon(Icons.delete_forever_outlined, color: AppColors.pink),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Delete account',
                            style: TextStyle(
                              color: AppColors.pink,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppGlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (iconColor ?? AppColors.text).withValues(alpha: 0.08),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.text, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.magenta,
          title: Text(
            title,
            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12))
              : null,
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.muted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help center'),
        content: const SingleChildScrollView(
          child: Text(
            'Discover mentors by skill, send a session request, and chat securely after they accept. '
            'Time tokens pay for sessions; teaching earns tokens back.\n\n'
            'Need help? Email support@knowmates.app',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of use'),
        content: const SingleChildScrollView(
          child: Text(
            'Use KnowMates respectfully. No harassment, spam, or misuse of sessions. '
            'You must be 18+. We may suspend accounts that violate community guidelines.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showBlockedInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Blocked accounts'),
        content: const Text(
          'Block someone from their profile menu while browsing Discover. '
          'Blocked users cannot request you and are hidden from your feed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    final uri = Uri.parse('https://knowmates.app/privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      _showTerms(context);
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.me, required this.onEdit});

  final Map<String, dynamic> me;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = me['displayName'] as String? ?? 'Member';
    final bio = me['bio'] as String? ?? '';
    final email = me['email'] as String? ?? '';
    final avatarUrl = me['avatarUrl'] as String? ?? '';
    final sessions = me['sessionsCompleted'] as int? ?? 0;
    final balance = me['balance'] as int? ?? 0;
    final rating = (me['ratingAvg'] as num?)?.toDouble() ?? 0;
    final ratingCount = me['ratingCount'] as int? ?? 0;
    final teachCount = me['teachCount'] as int? ?? 0;
    final learnCount = me['learnCount'] as int? ?? 0;
    final ratingLabel = ratingCount >= 3 ? rating.toStringAsFixed(1) : 'New';

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: AppColors.magenta.withValues(alpha: 0.2),
          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (email.isNotEmpty)
          Text(email, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.cardEdge),
            minimumSize: const Size(160, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: const Text('Edit profile'),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            _Stat(label: 'Sessions', value: '$sessions'),
            _Stat(label: 'Tokens', value: '$balance'),
            _Stat(label: 'Rating', value: ratingLabel),
            _Stat(label: 'Teaching', value: '$teachCount'),
            _Stat(label: 'Learning', value: '$learnCount'),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.me});

  final Map<String, dynamic> me;

  @override
  Widget build(BuildContext context) {
    final teach = _skills(me['teach']);
    final learn = _skills(me['learn']);
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teach.isNotEmpty) ...[
            const Text('Teaches', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final s in teach) Chip(label: Text(s))],
            ),
            const SizedBox(height: 14),
          ],
          if (learn.isNotEmpty) ...[
            const Text('Learning', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final s in learn) Chip(label: Text(s))],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _skills(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map && item['name'] != null) item['name'] as String,
    ];
  }
}
