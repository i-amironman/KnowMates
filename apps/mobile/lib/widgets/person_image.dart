import 'package:flutter/material.dart';

import '../models/person.dart';
import '../theme/app_colors.dart';

ImageProvider<Object>? personAvatarImage(Person person) {
  final url = person.avatarUrl;
  if (url.isEmpty) {
    return null;
  }
  if (url.startsWith('asset:')) {
    return AssetImage(url.substring('asset:'.length));
  }
  return NetworkImage(url);
}

Widget personPortrait({required Person person, required BoxFit fit}) {
  final provider = personAvatarImage(person);
  if (provider == null) {
    return _PortraitPlaceholder(initial: person.displayName);
  }
  return Image(
    image: provider,
    fit: fit,
    errorBuilder: (context, error, stackTrace) =>
        _PortraitPlaceholder(initial: person.displayName),
  );
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.radius = 24});

  final Person person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final provider = personAvatarImage(person);
    if (provider != null) {
      return CircleAvatar(radius: radius, backgroundImage: provider);
    }
    final initial = person.displayName.isNotEmpty
        ? person.displayName.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.magenta.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

class _PortraitPlaceholder extends StatelessWidget {
  const _PortraitPlaceholder({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final letter =
        initial.isNotEmpty ? initial.trim()[0].toUpperCase() : '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4A3058),
            Color(0xFF251830),
            Color(0xFF121014),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.text.withValues(alpha: 0.18),
          fontSize: 140,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
