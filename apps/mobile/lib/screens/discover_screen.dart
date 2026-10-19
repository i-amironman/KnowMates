import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../models/person.dart';
import '../setup/weekday.dart';
import '../theme/app_colors.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.people,
    required this.onRequest,
    required this.onSkip,
    required this.onOpen,
    this.onRefresh,
    this.filters,
  });

  final List<Person> people;
  final void Function(Person person) onRequest;
  final void Function(Person person) onSkip;
  final void Function(Person person) onOpen;
  final Future<void> Function()? onRefresh;
  final Widget? filters;

  @override
  Widget build(BuildContext context) {
    final body = people.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(
                child: Text(
                  'No partners match these filters yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: people.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _DiscoverCard(
                  person: people[index],
                  onRequest: onRequest,
                  onSkip: onSkip,
                  onOpen: onOpen,
                ),
              );
            },
          );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Discover'),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?filters,
          Expanded(
            child: onRefresh == null
                ? body
                : RefreshIndicator(
                    onRefresh: onRefresh!,
                    color: AppColors.magenta,
                    child: body,
                  ),
          ),
        ],
      ),
    );
  }
}

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.auth, required this.onOpenPerson});

  final AuthController auth;
  final void Function(Person person) onOpenPerson;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  List<Person> _people = const [];
  List<({String id, String name})> _learnSkills = const [];
  String? _skillId;
  String _language = '';
  int? _weekday;
  bool _loading = true;

  ApiClient get _client => widget.auth.client;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() => _loading = true);
      final meResp = await _client.get('/v1/me');
      if (meResp.statusCode == 200) {
        final me = jsonDecode(meResp.body) as Map<String, dynamic>;
        final learn = me['learn'];
        final skills = <({String id, String name})>[];
        if (learn is List) {
          for (final raw in learn) {
            final m = raw as Map<String, dynamic>;
            final id = m['skillId'] as String?;
            final name = m['name'] as String?;
            if (id != null && name != null) {
              skills.add((id: id, name: name));
            }
          }
        }
        _learnSkills = skills;
        _skillId = skills.isNotEmpty ? skills.first.id : null;
        final langs = me['languages'];
        if (_language.isEmpty && langs is List && langs.isNotEmpty) {
          _language = langs.first as String;
        }
      }
    }

    if (_skillId == null) {
      if (mounted) {
        setState(() {
          _people = const [];
          _loading = false;
        });
      }
      return;
    }

    final query = <String, String>{'skillId': _skillId!};
    if (_language.isNotEmpty) {
      query['language'] = _language;
    }
    if (_weekday != null) {
      query['weekday'] = '$_weekday';
    }

    final resp = await _client.get('/v1/discover', query: query);
    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = map['people'];
      _people = raw is List
          ? raw.cast<Map<String, dynamic>>().map(Person.fromJson).toList()
          : const [];
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _skip(Person person) {
    setState(() {
      _people = _people.where((p) => p.id != person.id).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.magenta),
        ),
      );
    }

    return DiscoverScreen(
      people: _people,
      onRequest: (_) {},
      onSkip: _skip,
      onOpen: widget.onOpenPerson,
      onRefresh: () => _load(),
      filters: _DiscoverFilters(
        learnSkills: _learnSkills,
        skillId: _skillId,
        language: _language,
        weekday: _weekday,
        onSkill: (id) {
          setState(() => _skillId = id);
          _load();
        },
        onLanguage: (code) {
          setState(() => _language = code);
          _load();
        },
        onWeekday: (day) {
          setState(() => _weekday = day);
          _load();
        },
      ),
    );
  }
}

class _DiscoverFilters extends StatelessWidget {
  const _DiscoverFilters({
    required this.learnSkills,
    required this.skillId,
    required this.language,
    required this.weekday,
    required this.onSkill,
    required this.onLanguage,
    required this.onWeekday,
  });

  final List<({String id, String name})> learnSkills;
  final String? skillId;
  final String language;
  final int? weekday;
  final ValueChanged<String> onSkill;
  final ValueChanged<String> onLanguage;
  final ValueChanged<int?> onWeekday;

  static const _langs = ['', 'en', 'es', 'hi'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (final s in learnSkills)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s.name),
                selected: skillId == s.id,
                onSelected: (_) => onSkill(s.id),
                selectedColor: AppColors.magenta.withValues(alpha: 0.35),
                checkmarkColor: AppColors.text,
                labelStyle: TextStyle(
                  color: skillId == s.id ? AppColors.text : AppColors.muted,
                ),
                side: const BorderSide(color: AppColors.cardEdge),
              ),
            ),
          for (final code in _langs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(code.isEmpty ? 'Any lang' : languageChipLabel(code)),
                selected: language == code,
                onSelected: (_) => onLanguage(code),
                selectedColor: AppColors.magenta.withValues(alpha: 0.35),
                checkmarkColor: AppColors.text,
                labelStyle: TextStyle(
                  color: language == code ? AppColors.text : AppColors.muted,
                ),
                side: const BorderSide(color: AppColors.cardEdge),
              ),
            ),
          FilterChip(
            label: const Text('Any day'),
            selected: weekday == null,
            onSelected: (_) => onWeekday(null),
            selectedColor: AppColors.magenta.withValues(alpha: 0.35),
            checkmarkColor: AppColors.text,
            side: const BorderSide(color: AppColors.cardEdge),
          ),
          for (var d = 0; d < kApiWeekdayLabels.length; d++)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(apiWeekdayLabel(d)),
                selected: weekday == d,
                onSelected: (_) => onWeekday(d),
                selectedColor: AppColors.magenta.withValues(alpha: 0.35),
                checkmarkColor: AppColors.text,
                side: const BorderSide(color: AppColors.cardEdge),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({
    required this.person,
    required this.onRequest,
    required this.onSkip,
    required this.onOpen,
  });

  final Person person;
  final void Function(Person person) onRequest;
  final void Function(Person person) onSkip;
  final void Function(Person person) onOpen;

  @override
  Widget build(BuildContext context) {
    final topProficiency = person.teach.isNotEmpty ? person.teach.first.proficiency : 1;
    final chips = person.teach.take(2).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardEdge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(person: person),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.displayName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        person.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in chips)
                  _SkillChip(label: t.name, proficiency: t.proficiency),
                for (final lang in person.languages)
                  Chip(
                    label: Text(languageChipLabel(lang)),
                    backgroundColor: AppColors.bg,
                    side: const BorderSide(color: AppColors.cardEdge),
                    labelStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${person.sessionsTaught} sessions',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Text(
                  '${person.ratingCount} reviews',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Text(
                  proficiencyLabel(topProficiency),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (person.showRating) ...[
                  const Spacer(),
                  const Icon(Icons.star, color: AppColors.star, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    person.ratingAvg.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => onRequest(person),
                  icon: const Icon(Icons.favorite_border, color: AppColors.magenta),
                  tooltip: 'Request',
                ),
                IconButton(
                  onPressed: () => onSkip(person),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                  tooltip: 'Skip',
                ),
                IconButton(
                  onPressed: () => onOpen(person),
                  icon: const Icon(Icons.info_outline, color: AppColors.text),
                  tooltip: 'Profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.proficiency});

  final String label;
  final int proficiency;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label · ${proficiencyLabel(proficiency)}'),
      backgroundColor: AppColors.bg,
      side: const BorderSide(color: AppColors.cardEdge),
      labelStyle: const TextStyle(color: AppColors.text, fontSize: 12),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    if (person.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(person.avatarUrl),
      );
    }
    final initial = person.displayName.isNotEmpty
        ? person.displayName.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.magenta,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
