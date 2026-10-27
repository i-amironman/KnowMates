import 'package:flutter/foundation.dart';

import '../models/person.dart';
import 'demo_requests.dart';

/// Demo discover feed with bundled portraits (see assets/mock/).
const kDiscoverUseMockData = false;

const _asset = 'asset:assets/mock/';

Person get discoverMockViewer => Person(
      id: 'mock-viewer',
      displayName: 'Alex Morgan',
      bio: '',
      languages: const ['en'],
      teach: const [],
      sessionsTaught: 0,
      ratingAvg: 0,
      ratingCount: 0,
      score: 0,
      avatarUrl: '${_asset}viewer_avatar.jpg',
    );

List<Person> get discoverMockPeople => [
      Person(
        id: 'mock-emma',
        displayName: 'Emma Thompson',
        bio:
            'Customer service expert transitioning into tech with 5+ years experience.',
        languages: const ['en', 'es'],
        teach: const [
          TeachSkill(
            skillId: seedWebDevSkillId,
            name: 'Web Development',
            proficiency: 4,
          ),
          TeachSkill(
            skillId: seedRunningSkillId,
            name: 'Running',
            proficiency: 3,
          ),
        ],
        sessionsTaught: 28,
        ratingAvg: 4.9,
        ratingCount: 28,
        score: 92,
        avatarUrl: '${_asset}emma_portrait.jpg',
      ),
      Person(
        id: 'mock-marcus',
        displayName: 'Marcus Lee',
        bio: 'Full-stack engineer mentoring beginners in React and system design.',
        languages: const ['en'],
        teach: const [
          TeachSkill(
            skillId: seedWebDevSkillId,
            name: 'Web Development',
            proficiency: 5,
          ),
          TeachSkill(
            skillId: seedMobileSkillId,
            name: 'Mobile Development',
            proficiency: 4,
          ),
        ],
        sessionsTaught: 42,
        ratingAvg: 4.8,
        ratingCount: 31,
        score: 88,
        avatarUrl: '${_asset}marcus_portrait.jpg',
      ),
      Person(
        id: 'mock-priya',
        displayName: 'Priya Sharma',
        bio: 'UX designer sharing research methods and portfolio reviews.',
        languages: const ['en', 'hi'],
        teach: const [
          TeachSkill(
            skillId: seedUiDesignSkillId,
            name: 'UI Design',
            proficiency: 4,
          ),
          TeachSkill(
            skillId: seedUiDesignSkillId,
            name: 'Figma',
            proficiency: 5,
          ),
        ],
        sessionsTaught: 19,
        ratingAvg: 4.7,
        ratingCount: 16,
        score: 85,
        avatarUrl: '${_asset}priya_portrait.jpg',
      ),
    ];

bool get discoverShouldUseMock =>
    kDiscoverUseMockData && kDebugMode;
