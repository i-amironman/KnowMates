import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../inbox/inbox_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/home_orb.dart';
import '../widgets/ui_kit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.inbox,
    this.onOpenNotifications,
  });

  final AuthController auth;
  final InboxController inbox;
  final VoidCallback? onOpenNotifications;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  int _sessionsCompleted = 0;
  int _balance = 0;
  int _teaching = 0;
  int _learning = 0;
  String _learnSkillName = '';
  double _ratingAvg = 0;
  int _ratingCount = 0;

  ApiClient get _client => widget.auth.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await _client.get('/v1/me');
    if (resp.statusCode == 200) {
      final me = jsonDecode(resp.body) as Map<String, dynamic>;
      _sessionsCompleted = me['sessionsCompleted'] as int? ?? 0;
      _balance = me['balance'] as int? ?? 0;
      _teaching =
          me['teachCount'] as int? ??
          (me['teach'] is List ? (me['teach'] as List).length : 0);
      _learning =
          me['learnCount'] as int? ??
          (me['learn'] is List ? (me['learn'] as List).length : 0);
      _ratingAvg = (me['ratingAvg'] as num?)?.toDouble() ?? 0;
      _ratingCount = me['ratingCount'] as int? ?? 0;
      final learn = me['learn'];
      if (learn is List && learn.isNotEmpty) {
        final first = learn.first as Map<String, dynamic>;
        _learnSkillName = first['name'] as String? ?? '';
      } else {
        _learnSkillName = '';
      }
    }
    await widget.inbox.refresh(_client);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String get _ratingText =>
      _ratingCount < 3 ? 'New' : '${_ratingAvg.toStringAsFixed(1)}/5.0';

  Widget _notificationButton() {
    final count = widget.inbox.unread;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _glassButton(
          Icons.notifications_none_rounded,
          'Notifications',
          widget.onOpenNotifications ?? () {},
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _glassButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.text.withValues(alpha: 0.06),
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.glassBorder),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 52,
            child: Icon(icon, color: AppColors.text, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(
          children: [
            _glassButton(Icons.refresh_rounded, 'Refresh', _load),
            const Expanded(
              child: Text(
                'Welcome back,',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _notificationButton(),
          ],
        ),
        const SizedBox(height: 28),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'AI',
                style: TextStyle(color: Color(0xFFCB2DBE)),
              ),
              TextSpan(text: '-Powered Skill'),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.text.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Text(
              'Exchange',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Advanced features for seamless learning',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.text.withValues(alpha: 0.65),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 18),
        const Center(child: HomeOrb()),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0D11),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.85,
            children: [
              AppStatTile(
                label: 'Sessions',
                value: '$_sessionsCompleted',
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFFFF9F43),
              ),
              AppStatTile(
                label: 'Time Tokens',
                value: '$_balance',
                icon: Icons.hourglass_bottom_rounded,
                iconColor: const Color(0xFF7C8CFF),
              ),
              AppStatTile(
                label: 'Teaching',
                value: _teaching.toStringAsFixed(1),
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFFFF4D8D),
              ),
              AppStatTile(
                label: 'Learning',
                value: _learning.toStringAsFixed(1),
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF7ED957),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_learnSkillName.isNotEmpty)
          AppGradientHighlightCard(
            title: _learnSkillName,
            subtitle: '$_sessionsCompleted sessions · Rating: $_ratingText',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppAmbientGlow(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.magenta),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.magenta,
                    child: _body(context),
                  ),
          ),
        ],
      ),
    );
  }
}
