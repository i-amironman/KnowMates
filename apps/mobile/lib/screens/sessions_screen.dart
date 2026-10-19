import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../call/join_window.dart';
import '../theme/app_colors.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<_SessionRow> _sessions = const [];
  List<_RequestRow> _acceptedRequests = const [];
  bool _loading = true;

  DateTime? _startLocal;
  DateTime? _endLocal;
  String? _scheduleRequestId;
  final _backupLinkCtrl = TextEditingController();

  ApiClient get _client => widget.auth.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _backupLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessResp = await _client.get('/v1/sessions');
    if (sessResp.statusCode == 200) {
      final map = jsonDecode(sessResp.body) as Map<String, dynamic>;
      final raw = map['sessions'];
      _sessions = raw is List
          ? raw.cast<Map<String, dynamic>>().map(_SessionRow.fromJson).toList()
          : const [];
    }
    final reqResp = await _client.get('/v1/requests');
    if (reqResp.statusCode == 200) {
      final map = jsonDecode(reqResp.body) as Map<String, dynamic>;
      final scheduledIds = _sessions.map((s) => s.requestId).toSet();
      final all = <_RequestRow>[];
      for (final key in ['incoming', 'sent']) {
        final raw = map[key];
        if (raw is List) {
          all.addAll(raw.cast<Map<String, dynamic>>().map(_RequestRow.fromJson));
        }
      }
      _acceptedRequests =
          all.where((r) => r.status == 'accepted' && !scheduledIds.contains(r.id)).toList();
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) {
      return;
    }
    setState(() {
      _startLocal = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_endLocal == null || !_endLocal!.isAfter(_startLocal!)) {
        _endLocal = _startLocal!.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final base = _startLocal ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) {
      return;
    }
    setState(() {
      _endLocal = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _schedule() async {
    final requestId = _scheduleRequestId;
    final start = _startLocal;
    final end = _endLocal;
    if (requestId == null || start == null || end == null || !end.isAfter(start)) {
      return;
    }
    await _client.post('/v1/sessions', body: {
      'requestId': requestId,
      'startsAt': start.toUtc().toIso8601String(),
      'endsAt': end.toUtc().toIso8601String(),
      if (_backupLinkCtrl.text.trim().isNotEmpty) 'meetingUrl': _backupLinkCtrl.text.trim(),
    });
    _backupLinkCtrl.clear();
    setState(() {
      _scheduleRequestId = null;
      _startLocal = null;
      _endLocal = null;
    });
    await _load();
  }

  Future<void> _complete(_SessionRow row) async {
    await _client.post('/v1/sessions/${row.id}/complete');
    await _load();
  }

  Future<void> _cancel(_SessionRow row) async {
    await _client.post('/v1/sessions/${row.id}/cancel');
    await _load();
  }

  Future<void> _review(_SessionRow row) async {
    var rating = 5;
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Review session', style: TextStyle(color: AppColors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate ${row.counterpartName}', style: const TextStyle(color: AppColors.muted)),
              Slider(
                value: rating.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$rating',
                activeColor: AppColors.magenta,
                onChanged: (v) => setLocal(() => rating = v.round()),
              ),
              TextField(
                controller: bodyCtrl,
                style: const TextStyle(color: AppColors.text),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Comment (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.magenta),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) {
      bodyCtrl.dispose();
      return;
    }
    await _client.post('/v1/sessions/${row.id}/reviews', body: {
      'rating': rating,
      'body': bodyCtrl.text.trim(),
    });
    bodyCtrl.dispose();
    await _load();
  }

  Future<void> _openBackup(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Sessions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.magenta))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.magenta,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_acceptedRequests.isNotEmpty) ...[
                    const Text(
                      'Schedule a session',
                      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      dropdownColor: AppColors.card,
                      value: _scheduleRequestId,
                      decoration: const InputDecoration(labelText: 'Accepted request'),
                      items: [
                        for (final r in _acceptedRequests)
                          DropdownMenuItem(
                            value: r.id,
                            child: Text('${r.skillName} · ${r.counterpartName}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _scheduleRequestId = v),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _startLocal == null ? 'Pick start (local time)' : _startLocal.toString(),
                        style: const TextStyle(color: AppColors.text),
                      ),
                      trailing: TextButton(onPressed: _pickStart, child: const Text('Start')),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _endLocal == null ? 'Pick end (local time)' : _endLocal.toString(),
                        style: const TextStyle(color: AppColors.text),
                      ),
                      trailing: TextButton(onPressed: _pickEnd, child: const Text('End')),
                    ),
                    TextField(
                      controller: _backupLinkCtrl,
                      style: const TextStyle(color: AppColors.text),
                      decoration: const InputDecoration(
                        labelText: 'Backup link (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _schedule,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.magenta),
                      child: const Text('Book session'),
                    ),
                    const SizedBox(height: 24),
                  ],
                  for (final s in _sessions) ...[
                    Card(
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
                            Text(
                              s.skillName,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(s.counterpartName, style: const TextStyle(color: AppColors.muted)),
                            Text(
                              '${s.startsAt.toLocal()} → ${s.endsAt.toLocal()}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12),
                            ),
                            Text(s.status, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            if (s.meetingUrl.isNotEmpty)
                              TextButton(
                                onPressed: () => _openBackup(s.meetingUrl),
                                child: const Text('Open backup link'),
                              ),
                            Row(
                              children: [
                                if (canJoin(DateTime.now().toUtc(), s.status, s.startsAt))
                                  TextButton(
                                    onPressed: () => context.push('/call/${s.id}'),
                                    child: const Text('Join'),
                                  ),
                                if (s.status == 'scheduled') ...[
                                  TextButton(onPressed: () => _complete(s), child: const Text('Complete')),
                                  TextButton(onPressed: () => _cancel(s), child: const Text('Cancel')),
                                ],
                                if (s.status == 'completed' && !s.reviewedByMe)
                                  TextButton(onPressed: () => _review(s), child: const Text('Leave review')),
                                if (s.status == 'completed' && s.reviewedByMe)
                                  const Text('Reviewed', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_sessions.isEmpty)
                    const Text('No sessions yet.', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
    );
  }
}

class _SessionRow {
  const _SessionRow({
    required this.id,
    required this.requestId,
    required this.skillName,
    required this.counterpartName,
    required this.startsAt,
    required this.endsAt,
    required this.meetingUrl,
    required this.status,
    required this.reviewedByMe,
  });

  final String id;
  final String requestId;
  final String skillName;
  final String counterpartName;
  final DateTime startsAt;
  final DateTime endsAt;
  final String meetingUrl;
  final String status;
  final bool reviewedByMe;

  factory _SessionRow.fromJson(Map<String, dynamic> json) {
    return _SessionRow(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      skillName: json['skillName'] as String? ?? '',
      counterpartName: json['counterpartName'] as String? ?? '',
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      meetingUrl: json['meetingUrl'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reviewedByMe: json['reviewedByMe'] as bool? ?? false,
    );
  }
}

class _RequestRow {
  const _RequestRow({
    required this.id,
    required this.status,
    required this.skillName,
    required this.counterpartName,
  });

  final String id;
  final String status;
  final String skillName;
  final String counterpartName;

  factory _RequestRow.fromJson(Map<String, dynamic> json) {
    return _RequestRow(
      id: json['id'] as String,
      status: json['status'] as String? ?? '',
      skillName: json['skillName'] as String? ?? '',
      counterpartName: json['counterpartName'] as String? ?? '',
    );
  }
}
