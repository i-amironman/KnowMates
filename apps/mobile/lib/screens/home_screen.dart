import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/home_orb.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.auth});

  final AuthController auth;

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
      _teaching = me['teachCount'] as int? ??
          (me['teach'] is List ? (me['teach'] as List).length : 0);
      _learning = me['learnCount'] as int? ??
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
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String get _ratingText =>
      _ratingCount < 3 ? 'New' : '${_ratingAvg.toStringAsFixed(1)}/5';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.magenta,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh, color: AppColors.muted),
                          tooltip: 'Refresh',
                        ),
                        const Expanded(
                          child: Text(
                            'Welcome back,',
                            style: TextStyle(color: AppColors.muted, fontSize: 16),
                          ),
                        ),
                        const Offstage(
                          offstage: true,
                          child: Icon(Icons.notifications_outlined, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const _HomeWordmark(),
                    const SizedBox(height: 8),
                    const Text(
                      'Learn from people. Grow together.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    const Center(child: HomeOrb()),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _StatCard(label: 'Sessions', value: '$_sessionsCompleted'),
                        _StatCard(label: 'Time Tokens', value: '$_balance'),
                        _StatCard(label: 'Teaching', value: '$_teaching'),
                        _StatCard(label: 'Learning', value: '$_learning'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_learnSkillName.isNotEmpty)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardEdge),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _learnSkillName,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_sessionsCompleted sessions',
                                      style: const TextStyle(color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _ratingText,
                                style: const TextStyle(
                                  color: AppColors.star,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardEdge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Know',
          style: TextStyle(
            color: AppColors.magenta,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardEdge),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Mates',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
