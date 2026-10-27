import 'package:flutter/foundation.dart';

/// In debug mock-discover mode, session requests stay on-device (no API teacher row).
class DemoRequestsController extends ChangeNotifier {
  final List<DemoRequestRow> sent = [];

  void addSent({
    required String teacherId,
    required String teacherName,
    required String skillId,
    required String skillName,
    required String goal,
  }) {
    sent.insert(
      0,
      DemoRequestRow(
        id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
        teacherId: teacherId,
        teacherName: teacherName,
        skillId: skillId,
        skillName: skillName,
        goal: goal,
        status: 'pending',
      ),
    );
    notifyListeners();
  }
}

class DemoRequestRow {
  DemoRequestRow({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.skillId,
    required this.skillName,
    required this.goal,
    required this.status,
  });

  final String id;
  final String teacherId;
  final String teacherName;
  final String skillId;
  final String skillName;
  final String goal;
  final String status;
}

bool isMockPersonId(String id) => id.startsWith('mock-');

const seedWebDevSkillId = '11111111-1111-4111-8111-111111111101';
const seedRunningSkillId = '11111111-1111-4111-8111-111111111107';
const seedMobileSkillId = '11111111-1111-4111-8111-111111111102';
const seedUiDesignSkillId = '11111111-1111-4111-8111-111111111103';

final uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isUuid(String value) => uuidPattern.hasMatch(value);
