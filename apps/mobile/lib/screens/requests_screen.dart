import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../inbox/inbox_controller.dart';
import '../mock/demo_requests.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.auth,
    required this.inbox,
    this.demoRequests,
    this.onOpenChat,
  });

  final AuthController auth;
  final InboxController inbox;
  final DemoRequestsController? demoRequests;
  final void Function({required String threadId, required String name})? onOpenChat;

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
    widget.demoRequests?.addListener(_onDemoChanged);
    _load();
  }

  @override
  void dispose() {
    widget.demoRequests?.removeListener(_onDemoChanged);
    super.dispose();
  }

  void _onDemoChanged() {
    if (!mounted || _loading) {
      return;
    }
    setState(() => _sent = _mergeDemoSent(_sent));
  }

  List<_RequestRow> _mergeDemoSent(List<_RequestRow> apiSent) {
    final demo = widget.demoRequests?.sent ?? const [];
    final demoRows = demo
        .map(
          (d) => _RequestRow(
            id: d.id,
            goal: d.goal,
            status: d.status,
            skillName: d.skillName,
            counterpartName: d.teacherName,
          ),
        )
        .toList();
    final apiOnly = apiSent.where((r) => !r.id.startsWith('demo-')).toList();
    return [...demoRows, ...apiOnly];
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await _client.get('/v1/requests');
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      _incoming = _parseList(map['incoming']);
      _sent = _mergeDemoSent(_parseList(map['sent']));
    } else {
      _sent = _mergeDemoSent(const []);
    }
    await widget.inbox.refresh(_client);
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
    final resp = await _client.post('/v1/requests/${row.id}/accept');
    await _load();
    if (!mounted || resp.statusCode != 204) {
      return;
    }
    _RequestRow? updated;
    for (final r in [..._incoming, ..._sent]) {
      if (r.id == row.id) {
        updated = r;
        break;
      }
    }
    final threadId = updated?.chatThreadId;
    if (threadId != null && widget.onOpenChat != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request accepted. Secure chat is ready.'),
          action: SnackBarAction(
            label: 'Open chat',
            onPressed: () => widget.onOpenChat!(
              threadId: threadId,
              name: row.counterpartName,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _decline(_RequestRow row) async {
    await _client.post('/v1/requests/${row.id}/decline');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Requests'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.magenta,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const AppSectionHeader('Incoming'),
                  ..._incoming.map((r) => _RequestTile(
                        row: r,
                        onAccept: r.status == 'pending' ? () => _accept(r) : null,
                        onDecline: r.status == 'pending' ? () => _decline(r) : null,
                        onChat: r.chatThreadId != null && widget.onOpenChat != null
                            ? () => widget.onOpenChat!(
                                  threadId: r.chatThreadId!,
                                  name: r.counterpartName,
                                )
                            : null,
                      )),
                  if (_incoming.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No incoming requests.', style: TextStyle(color: AppColors.muted)),
                    ),
                  const SizedBox(height: 16),
                  const AppSectionHeader('Sent'),
                  ..._sent.map((r) => _RequestTile(
                        row: r,
                        onChat: r.chatThreadId != null && widget.onOpenChat != null
                            ? () => widget.onOpenChat!(
                                  threadId: r.chatThreadId!,
                                  name: r.counterpartName,
                                )
                            : null,
                      )),
                  if (_sent.isEmpty)
                    const Text('No sent requests.', style: TextStyle(color: AppColors.muted)),
                ],
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
    this.onChat,
  });

  final _RequestRow row;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.counterpartName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
          Text(row.skillName, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(row.goal, style: const TextStyle(color: AppColors.text)),
          Text(row.status, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if (onAccept != null || onDecline != null || onChat != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onAccept != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.magenta),
                      child: const Text('Accept'),
                    ),
                  ),
                if (onAccept != null && onDecline != null) const SizedBox(width: 10),
                if (onDecline != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        side: const BorderSide(color: AppColors.cardEdge),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
              ],
            ),
            if (onChat != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Secure chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.online,
                    side: const BorderSide(color: AppColors.online),
                  ),
                ),
              ),
            ],
          ],
        ],
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
    this.chatThreadId,
  });

  final String id;
  final String goal;
  final String status;
  final String skillName;
  final String counterpartName;
  final String? chatThreadId;

  factory _RequestRow.fromJson(Map<String, dynamic> json) {
    return _RequestRow(
      id: json['id'] as String,
      goal: json['goal'] as String? ?? '',
      status: json['status'] as String? ?? '',
      skillName: json['skillName'] as String? ?? '',
      counterpartName: json['counterpartName'] as String? ?? '',
      chatThreadId: json['chatThreadId'] as String?,
    );
  }
}
