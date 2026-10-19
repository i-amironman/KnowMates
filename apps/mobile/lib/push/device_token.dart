import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/client.dart';

/// Posts the FCM registration token when Firebase is configured on device.
Future<void> registerDeviceToken(ApiClient client) async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
    return;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await client.post('/v1/me/device', body: {'token': token}, auth: true);
  } catch (_) {
    // ponytail: no google-services.json / FCM setup yet — sessions tab still works
  }
}
