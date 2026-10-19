import 'package:flutter/material.dart';

import '../models/person.dart';
import '../theme/app_colors.dart';

class PersonScreen extends StatelessWidget {
  const PersonScreen({
    super.key,
    required this.person,
    this.onRequest,
  });

  final Person person;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
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
          if (onRequest != null)
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.favorite),
              label: const Text('Request to learn'),
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
