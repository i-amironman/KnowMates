import 'package:flutter/material.dart';

import '../api/client.dart';
import '../models/person.dart';
import '../theme/app_colors.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.person.teach.isNotEmpty) {
      _skillId = widget.person.teach.first.skillId;
    }
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestSession() async {
    final goal = _goalCtrl.text.trim();
    final skillId = _skillId ?? widget.learnSkillId;
    if (skillId == null || skillId.isEmpty) {
      setState(() => _error = 'Pick a skill to learn.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
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
    setState(() {
      _sending = false;
      _error = apiErrorMessage(resp) ?? 'Could not send request.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(person.displayName),
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
                for (final t in person.teach)
                  DropdownMenuItem(value: t.skillId, child: Text(t.name)),
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
              hintText: 'What do you want to get from this session?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.pink)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _requestSession,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                  )
                : const Icon(Icons.favorite),
            label: const Text('Request session'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.magenta,
              minimumSize: const Size.fromHeight(52),
            ),
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
    if (person.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(person.avatarUrl),
      );
    }
    final initial = person.displayName.isNotEmpty
        ? person.displayName.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.magenta,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
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
