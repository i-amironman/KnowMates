import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../credit/ledger_label.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _balance = 0;
  List<_LedgerRow> _entries = const [];
  bool _loading = true;

  ApiClient get _client => widget.auth.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await _client.get('/v1/wallet');
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      _balance = map['balance'] as int? ?? 0;
      final raw = map['entries'];
      _entries = raw is List
          ? raw.cast<Map<String, dynamic>>().map(_LedgerRow.fromJson).toList()
          : const [];
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Time wallet'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.magenta,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppGlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_balance',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Time Tokens', style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const AppSectionHeader('Activity'),
                  for (final e in _entries)
                    AppGlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ledgerLabel(e.reason),
                              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            e.delta >= 0 ? '+${e.delta}' : '${e.delta}',
                            style: TextStyle(
                              color: e.delta >= 0 ? AppColors.star : AppColors.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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
}

class _LedgerRow {
  const _LedgerRow({required this.reason, required this.delta});

  final String reason;
  final int delta;

  factory _LedgerRow.fromJson(Map<String, dynamic> json) {
    return _LedgerRow(
      reason: json['reason'] as String? ?? '',
      delta: json['delta'] as int? ?? 0,
    );
  }
}
