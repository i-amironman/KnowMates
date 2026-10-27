import 'package:flutter/material.dart';

import '../api/client.dart';
import '../mock/demo_requests.dart';
import '../models/person.dart';
import '../theme/app_colors.dart';
import '../widgets/person_image.dart';
import '../widgets/ui_kit.dart';

class PersonScreen extends StatefulWidget {
  const PersonScreen({
    super.key,
    required this.person,
    required this.client,
    this.learnSkillId,
  });

  final Person person;
  final ApiClient client;
  final String? learnSkillId;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final _goalCtrl = TextEditingController();
  String? _skillId;
  bool _sending = false;

  static String _teachOptionValue(TeachSkill skill, int index) {
    if (skill.skillId.isNotEmpty) {
      return skill.skillId;
    }
    return 'local-$index-${skill.name}';
  }

  String? _apiSkillIdForSelection(String? selected) {
    if (selected == null) {
      return widget.learnSkillId;
    }
    for (var i = 0; i < widget.person.teach.length; i++) {
      final t = widget.person.teach[i];
      if (_teachOptionValue(t, i) == selected) {
        return t.skillId.isNotEmpty ? t.skillId : widget.learnSkillId;
      }
    }
    return widget.learnSkillId;
  }

  @override
  void initState() {
    super.initState();
    if (widget.person.teach.isNotEmpty) {
      _skillId = _teachOptionValue(widget.person.teach.first, 0);
    }
    _goalCtrl.addListener(() => setState(() {}));
  }

  bool get _goalValid => _goalCtrl.text.trim().runes.length >= 8;

  String? get _selectedSkillName {
    final selected = _apiSkillIdForSelection(_skillId);
    if (selected == null) {
      return null;
    }
    for (final t in widget.person.teach) {
      if (t.skillId == selected) {
        return t.name;
      }
    }
    return widget.person.teach.isNotEmpty ? widget.person.teach.first.name : null;
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _blockUser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text('They will not appear in discovery and cannot request you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    final resp = await widget.client.post('/v1/blocks', body: {'userId': widget.person.id});
    if (!mounted) {
      return;
    }
    if (resp.statusCode == 204) {
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(resp) ?? 'Could not block.')),
    );
  }

  Future<void> _reportUser() async {
    final result = await showDialog<({String reason, String details})>(
      context: context,
      builder: (ctx) => _ReportDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    final resp = await widget.client.post('/v1/reports', body: {
      'userId': widget.person.id,
      'reason': result.reason,
      'details': result.details,
    });
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resp.statusCode == 204 ? 'Report submitted.' : (apiErrorMessage(resp) ?? 'Could not report.'),
        ),
      ),
    );
  }

  Future<void> _requestSession() async {
    final goal = _goalCtrl.text.trim();
    final skillId = _apiSkillIdForSelection(_skillId);
    if (skillId == null || skillId.isEmpty || !_goalValid) {
      return;
    }
    setState(() => _sending = true);

    if (!isUuid(widget.person.id) || !isUuid(skillId)) {
      if (mounted) {
        setState(() => _sending = false);
        Navigator.of(context).pop();
      }
      return;
    }

    final resp = await widget.client.post('/v1/requests', body: {
      'teacherId': widget.person.id,
      'skillId': skillId,
      'goal': goal,
    });
    if (!mounted) {
      return;
    }
    if (resp.statusCode == 201) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          person.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _blockUser();
              } else if (value == 'report') {
                _reportUser();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'block', child: Text('Block')),
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _LargeAvatar(person: person)),
          const SizedBox(height: 16),
          Text(
            person.bio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final lang in person.languages)
                Chip(
                  label: Text(languageChipLabel(lang)),
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.cardEdge),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Teaches',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          for (final t in person.teach)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.name, style: const TextStyle(color: AppColors.text)),
              trailing: Text(
                proficiencyLabel(t.proficiency),
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatTile(label: 'Sessions', value: '${person.sessionsTaught}'),
              _StatTile(label: 'Reviews', value: '${person.ratingCount}'),
              if (person.showRating)
                _StatTile(
                  label: 'Rating',
                  value: person.ratingAvg.toStringAsFixed(1),
                ),
            ],
          ),
          const SizedBox(height: 32),
          if (person.teach.length > 1)
            DropdownButtonFormField<String>(
              value: _skillId,
              dropdownColor: AppColors.card,
              decoration: const InputDecoration(labelText: 'Skill'),
              items: [
                for (var i = 0; i < person.teach.length; i++)
                  DropdownMenuItem(
                    value: _teachOptionValue(person.teach[i], i),
                    child: Text(person.teach[i].name),
                  ),
              ],
              onChanged: (v) => setState(() => _skillId = v),
            ),
          TextField(
            controller: _goalCtrl,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              labelText: 'Your learning goal',
              hintText: 'What do you want to get from this session? (min. 8 characters)',
            ),
          ),
          const SizedBox(height: 16),
          AppGradientButton(
            label: 'Request session',
            icon: Icons.favorite_rounded,
            loading: _sending,
            onPressed: _sending || !_goalValid ? null : _requestSession,
          ),
        ],
      ),
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return PersonAvatar(person: person, radius: 48);
  }
}

class _ReportDialog extends StatefulWidget {
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = 'other';
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: const [
              DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
              DropdownMenuItem(value: 'spam', child: Text('Spam')),
              DropdownMenuItem(value: 'safety', child: Text('Safety')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _reason = v ?? 'other'),
          ),
          TextField(
            controller: _detailsCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (reason: _reason, details: _detailsCtrl.text.trim())),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

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
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}
