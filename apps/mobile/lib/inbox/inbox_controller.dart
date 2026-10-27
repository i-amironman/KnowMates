import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/client.dart';

/// Tracks unread in-app notifications for the home bell badge.
class InboxController extends ChangeNotifier {
  int unread = 0;

  Future<void> refresh(ApiClient client) async {
    final resp = await client.get('/v1/notifications/unread-count');
    if (resp.statusCode != 200) {
      return;
    }
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final n = map['unread'] as int? ?? 0;
    if (n != unread) {
      unread = n;
      notifyListeners();
    }
  }

  Future<void> markAllRead(ApiClient client) async {
    await client.post('/v1/notifications/read', body: {});
    unread = 0;
    notifyListeners();
  }
}
