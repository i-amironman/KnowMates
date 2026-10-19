import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<_RequestRow> _incoming = const [];
  List<_RequestRow> _sent = const [];
  bool _loading = true;

  ApiClient get _client => widget.auth.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await _client.get('/v1/requests');
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      _incoming = _parseList(map['incoming']);
      _sent = _parseList(map['sent']);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  List<_RequestRow> _parseList(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.cast<Map<String, dynamic>>().map(_RequestRow.fromJson).toList();
  }

  Future<void> _accept(_RequestRow row) async {
    await _client.post('/v1/requests/${row.id}/accept');
    await _load();
  }

  Future<void> _decline(_RequestRow row) async {
    await _client.post('/v1/requests/${row.id}/decline');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Requests'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.magenta,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SectionTitle('Incoming'),
                  ..._incoming.map((r) => _RequestTile(
                        row: r,
                        onAccept: r.status == 'pending' ? () => _accept(r) : null,
                        onDecline: r.status == 'pending' ? () => _decline(r) : null,
                      )),
                  if (_incoming.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No incoming requests.', style: TextStyle(color: AppColors.muted)),
                    ),
                  const SizedBox(height: 16),
                  const _SectionTitle('Sent'),
                  ..._sent.map((r) => _RequestTile(row: r)),
                  if (_sent.isEmpty)
                    const Text('No sent requests.', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.row,
    this.onAccept,
    this.onDecline,
  });

  final _RequestRow row;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardEdge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.counterpartName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
            Text(row.skillName, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text(row.goal, style: const TextStyle(color: AppColors.text)),
            Text(row.status, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            if (onAccept != null || onDecline != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onAccept != null)
                    TextButton(onPressed: onAccept, child: const Text('Accept')),
                  if (onDecline != null)
                    TextButton(onPressed: onDecline, child: const Text('Decline')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestRow {
  const _RequestRow({
    required this.id,
    required this.goal,
    required this.status,
    required this.skillName,
    required this.counterpartName,
  });

  final String id;
  final String goal;
  final String status;
  final String skillName;
  final String counterpartName;

  factory _RequestRow.fromJson(Map<String, dynamic> json) {
    return _RequestRow(
      id: json['id'] as String,
      goal: json['goal'] as String? ?? '',
      status: json['status'] as String? ?? '',
      skillName: json['skillName'] as String? ?? '',
      counterpartName: json['counterpartName'] as String? ?? '',
    );
  }
}
