import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../setup/weekday.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _page = PageController();
  int _step = 0;
  final _languages = <String>{};
  List<SkillOption> _skills = const [];
  final _teach = <String>{};
  final _learn = <String>{};
  final _slots = <_AvailSlot>[];
  int _weekday = kDefaultApiWeekday;
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 20, minute: 0);
  String? _error;
  bool _busy = false;

  static const _languageOptions = ['en', 'es', 'hi'];

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final skills = await widget.auth.fetchSkills();
    if (mounted) {
      setState(() => _skills = skills);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && _languages.isEmpty) {
      setState(() => _error = 'Pick at least one language.');
      return;
    }
    if (_step == 1 && (_teach.isEmpty || _learn.isEmpty)) {
      setState(() => _error = 'Pick at least one teach and one learn skill.');
      return;
    }
    setState(() => _error = null);
    if (_step < 1) {
      setState(() => _step++);
      _page.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    _finish();
  }

  Future<void> _finish() async {
    if (_slots.isEmpty) {
      setState(() => _error = 'Add at least one availability slot.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await widget.auth.completeSetup(
      languages: _languages.toList(),
      teach: [
        for (final id in _teach)
          {'skillId': id, 'proficiency': 3},
      ],
      learn: [
        for (final id in _learn)
          {'skillId': id, 'proficiency': 2},
      ],
      slots: [for (final s in _slots) s.toJson()],
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  void _addSlot() {
    final startMin = _start.hour * 60 + _start.minute;
    final endMin = _end.hour * 60 + _end.minute;
    if (endMin <= startMin) {
      setState(() => _error = 'End time must be after start.');
      return;
    }
    setState(() {
      _error = null;
      _slots.add(_AvailSlot(weekday: _weekday, startMin: startMin, endMin: endMin));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      appBar: AppTopBar(title: 'Setup'),
      body: Column(
        children: [
          AppSetupProgress(step: _step, total: 2),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const AppSectionHeader('Languages you speak'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final code in _languageOptions)
                          AppFilterChip(
                            label: code,
                            selected: _languages.contains(code),
                            onSelected: (on) {
                              setState(() {
                                if (on) {
                                  _languages.add(code);
                                } else {
                                  _languages.remove(code);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const AppSectionHeader('Skills you teach'),
                    if (_skills.isEmpty)
                      const Text('No skills loaded yet.', style: TextStyle(color: AppColors.muted))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final skill in _skills)
                            AppFilterChip(
                              label: skill.name,
                              selected: _teach.contains(skill.id),
                              onSelected: (on) {
                                setState(() {
                                  if (on) {
                                    _teach.add(skill.id);
                                  } else {
                                    _teach.remove(skill.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const AppSectionHeader('Skills you want to learn'),
                    if (_skills.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final skill in _skills)
                            AppFilterChip(
                              label: skill.name,
                              selected: _learn.contains(skill.id),
                              onSelected: (on) {
                                setState(() {
                                  if (on) {
                                    _learn.add(skill.id);
                                  } else {
                                    _learn.remove(skill.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const AppSectionHeader('Weekly hours'),
                    DropdownButton<int>(
                      value: _weekday,
                      items: [
                        for (var i = 0; i < 7; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(apiWeekdayLabel(i)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _weekday = v);
                        }
                      },
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _start,
                            );
                            if (picked != null) {
                              setState(() => _start = picked);
                            }
                          },
                          child: Text('Start ${_start.format(context)}'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _end,
                            );
                            if (picked != null) {
                              setState(() => _end = picked);
                            }
                          },
                          child: Text('End ${_end.format(context)}'),
                        ),
                        TextButton(onPressed: _addSlot, child: const Text('Add')),
                      ],
                    ),
                    for (final slot in _slots)
                      Text(
                        '${apiWeekdayLabel(slot.weekday)} '
                        '${slot.startMin ~/ 60}:${(slot.startMin % 60).toString().padLeft(2, '0')}–'
                        '${slot.endMin ~/ 60}:${(slot.endMin % 60).toString().padLeft(2, '0')}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.pink),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: AppGradientButton(
              label: _step < 1 ? 'Next' : (_busy ? 'Saving…' : 'Finish'),
              loading: _busy,
              onPressed: _busy ? null : _next,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailSlot {
  const _AvailSlot({
    required this.weekday,
    required this.startMin,
    required this.endMin,
  });

  final int weekday;
  final int startMin;
  final int endMin;

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'startMin': startMin,
    'endMin': endMin,
  };
}
