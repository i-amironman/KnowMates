import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../auth/auth_controller.dart';
import '../models/person.dart';
import '../setup/weekday.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../widgets/person_image.dart';
import '../widgets/ui_kit.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.people,
    required this.onRequest,
    required this.onSkip,
    required this.onOpen,
    this.onRefresh,
    this.onMenuTap,
    this.profileAvatar,
  });

  final List<Person> people;
  final void Function(Person person) onRequest;
  final void Function(Person person) onSkip;
  final void Function(Person person) onOpen;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onMenuTap;
  final Widget? profileAvatar;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final listPadding = layout.screenPadding.copyWith(top: 4);

    final body = people.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: listPadding,
            children: const [
              SizedBox(height: 80),
              Center(
                child: Text(
                  'No mentors match yet. Try another skill or language filter, or check back when more members join.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          )
        : ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: listPadding,
            children: [
              _DiscoverCard(
                person: people.first,
                onRequest: onRequest,
                onSkip: onSkip,
                onOpen: onOpen,
              ),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppAmbientGlow(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(
                title: 'Discover',
                showMenu: true,
                showDiscoverMark: true,
                glassChrome: true,
                onMenu: onMenuTap,
                trailing: profileAvatar ??
                    ClipOval(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.glassBorder, width: 1.5),
                          color: AppColors.cardElevated,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.muted,
                          size: 22,
                        ),
                      ),
                    ),
              ),
              Expanded(
                child: onRefresh == null
                    ? body
                    : RefreshIndicator(
                        onRefresh: onRefresh!,
                        color: AppColors.magenta,
                        edgeOffset: 8,
                        child: body,
                      ),
              ),
            ],
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
  String _myInitial = '?';
  String _myUserId = '';
  String _myAvatarUrl = '';

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
        _myUserId = me['id'] as String? ?? '';
        _myAvatarUrl = me['avatarUrl'] as String? ?? '';
        final displayName = me['displayName'] as String? ?? '';
        if (displayName.isNotEmpty) {
          _myInitial = displayName.trim()[0].toUpperCase();
        }
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
      final all = raw is List
          ? raw.cast<Map<String, dynamic>>().map(Person.fromJson).toList()
          : const <Person>[];
      _people = [
        for (final p in all)
          if (p.id != _myUserId) p,
      ];
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

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _DiscoverFilters(
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
            ],
          ),
        ),
      ),
    );
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

    if (_learnSkills.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Add at least one skill you want to learn in your profile setup to see mentors in Discover.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9)),
            ),
          ),
        ),
      );
    }

    return DiscoverScreen(
      people: _people,
      onRequest: (_) {},
      onSkip: _skip,
      onOpen: widget.onOpenPerson,
      onRefresh: () => _load(),
      onMenuTap: _openFilters,
      profileAvatar: _myAvatarUrl.isNotEmpty
          ? CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(_myAvatarUrl),
            )
          : CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.cardElevated,
              child: Text(
                _myInitial,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in learnSkills)
          AppFilterChip(
            label: s.name,
            selected: skillId == s.id,
            onSelected: (_) => onSkill(s.id),
          ),
        for (final code in _langs)
          AppFilterChip(
            label: code.isEmpty ? 'Any lang' : languageChipLabel(code),
            selected: language == code,
            onSelected: (_) => onLanguage(code),
          ),
        AppFilterChip(
          label: 'Any day',
          selected: weekday == null,
          onSelected: (_) => onWeekday(null),
        ),
        for (var d = 0; d < kApiWeekdayLabels.length; d++)
          AppFilterChip(
            label: apiWeekdayLabel(d),
            selected: weekday == d,
            onSelected: (_) => onWeekday(d),
          ),
      ],
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
    final layout = AppLayout.of(context);
    final topProficiency = person.teach.isNotEmpty ? person.teach.first.proficiency : 1;
    final chips = person.teach.take(2).toList();
    final experienceYears = (person.sessionsTaught / 6).round().clamp(1, 99);
    final experienceLabel = '$experienceYears years experience';
    final styleLabel =
        topProficiency >= 3 ? 'Style' : proficiencyLabel(topProficiency);
    final cardPad = layout.compact ? 12.0 : 16.0;
    final avatarRadius = layout.veryCompact ? 20.0 : (layout.compact ? 22.0 : 24.0);

    return AppGlassCard(
      padding: EdgeInsets.all(cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(person: person, radius: avatarRadius),
              SizedBox(width: layout.gap(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            person.displayName,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: layout.font(18),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (person.sessionsTaught >= 10) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            color: const Color(0xFF5AC8FA),
                            size: layout.compact ? 16 : 18,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: layout.gap(4)),
                    Text(
                      experienceLabel,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: layout.font(13),
                      ),
                    ),
                  ],
                ),
              ),
              AppGlassIconButton(
                icon: Icons.bookmark_border_rounded,
                size: layout.compact ? 36 : 40,
                onPressed: () {},
              ),
            ],
          ),
          if (person.bio.isNotEmpty) ...[
            SizedBox(height: layout.gap(10)),
            Text(
              person.bio,
              maxLines: layout.veryCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: layout.font(14),
                height: 1.4,
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            SizedBox(height: layout.gap(12)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in chips) _SkillTag(label: t.name),
              ],
            ),
          ],
          SizedBox(height: layout.gap(14)),
          LayoutBuilder(
            builder: (context, constraints) {
              final photoHeight =
                  layout.discoverPhotoHeight(constraints.maxWidth);
              return ClipRRect(
                borderRadius: BorderRadius.circular(layout.compact ? 18 : 22),
                child: SizedBox(
                  height: photoHeight,
                  width: constraints.maxWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      personPortrait(person: person, fit: BoxFit.cover),
                      Positioned(
                        top: layout.gap(8),
                        left: 0,
                        right: 0,
                        child: Center(child: _OnlineBadge()),
                      ),
                      Positioned(
                        left: 4,
                        right: 4,
                        bottom: layout.gap(8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppDiscoverActionPill(
                                icon: Icons.favorite_rounded,
                                label: 'Like',
                                accent: true,
                                onPressed: () => onRequest(person),
                              ),
                              AppDiscoverActionPill(
                                icon: Icons.close_rounded,
                                label: 'Cancel',
                                onPressed: () => onSkip(person),
                              ),
                              AppDiscoverActionPill(
                                icon: Icons.info_outline_rounded,
                                label: 'Information',
                                onPressed: () => onOpen(person),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: layout.gap(14)),
          Container(
            padding: EdgeInsets.all(layout.compact ? 12 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141416).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(layout.compact ? 16 : 20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Skills',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: layout.font(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (person.showRating) ...[
                      Icon(
                        Icons.star_rounded,
                        color: AppColors.star,
                        size: layout.compact ? 18 : 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        person.ratingAvg.toStringAsFixed(1),
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: layout.font(16),
                        ),
                      ),
                    ],
                  ],
                ),
                if (person.languages.isNotEmpty) ...[
                  SizedBox(height: layout.gap(12)),
                  Text(
                    'Languages:',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: layout.font(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: layout.gap(8)),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final lang in person.languages)
                        _LanguagePill(code: lang),
                    ],
                  ),
                ],
                SizedBox(height: layout.gap(14)),
                _StatsStrip(
                  sessions: person.sessionsTaught,
                  reviews: person.ratingCount,
                  styleLabel: styleLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.online,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Online',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.sessions,
    required this.reviews,
    required this.styleLabel,
  });

  final int sessions;
  final int reviews;
  final String styleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardElevated.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          _StatCell(label: 'Sessions', value: '$sessions'),
          _statDivider(),
          _StatCell(label: 'Reviews', value: '$reviews'),
          _statDivider(),
          _StatCell(label: 'Interactive Style', value: styleLabel),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.glassBorder,
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: layout.font(16),
            ),
          ),
          SizedBox(height: layout.gap(4)),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: layout.font(10),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.compact ? 12 : 14,
        vertical: layout.compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardElevated.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        discoverLanguageLabel(code),
        style: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: layout.font(13),
        ),
      ),
    );
  }
}

class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.compact ? 12 : 16,
        vertical: layout.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: layout.font(13),
        ),
      ),
    );
  }
}

String discoverLanguageLabel(String code) {
  switch (code) {
    case 'en':
      return '🇬🇧  English';
    case 'es':
      return '🇪🇸  Spanish';
    case 'hi':
      return '🇮🇳  Hindi';
    default:
      return code;
  }
}
