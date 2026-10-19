class TeachSkill {
  const TeachSkill({
    this.skillId = '',
    required this.name,
    required this.proficiency,
  });

  final String skillId;
  final String name;
  final int proficiency;

  factory TeachSkill.fromJson(Map<String, dynamic> json) {
    return TeachSkill(
      skillId: json['skillId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      proficiency: json['proficiency'] as int? ?? 1,
    );
  }
}

class Person {
  const Person({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.languages,
    required this.teach,
    required this.sessionsTaught,
    required this.ratingAvg,
    required this.ratingCount,
    required this.score,
    this.avatarUrl = '',
  });

  final String id;
  final String displayName;
  final String bio;
  final List<String> languages;
  final List<TeachSkill> teach;
  final int sessionsTaught;
  final double ratingAvg;
  final int ratingCount;
  final int score;
  final String avatarUrl;

  bool get showRating => ratingCount >= 3;

  factory Person.fromJson(Map<String, dynamic> json) {
    final teachRaw = json['teach'];
    return Person(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      teach: teachRaw is List
          ? teachRaw
              .cast<Map<String, dynamic>>()
              .map(TeachSkill.fromJson)
              .toList()
          : const [],
      sessionsTaught: json['sessionsTaught'] as int? ?? 0,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}

String proficiencyLabel(int level) {
  switch (level) {
    case 1:
      return 'Basics';
    case 2:
      return 'Guided';
    case 3:
      return 'Practice';
    case 4:
      return 'Deep dive';
    case 5:
      return 'Mentor';
    default:
      return 'Basics';
  }
}

String languageChipLabel(String code) {
  switch (code) {
    case 'en':
      return '🇺🇸 en';
    case 'es':
      return '🇪🇸 es';
    case 'hi':
      return '🇮🇳 hi';
    default:
      return code;
  }
}
