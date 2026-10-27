import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local notification & privacy toggles (device-only until settings API exists).
class ProfilePrefs {
  ProfilePrefs({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _push = 'profile_pref_push';
  static const _email = 'profile_pref_email';
  static const _sessionReminders = 'profile_pref_session_reminders';
  static const _chatAlerts = 'profile_pref_chat_alerts';
  static const _discoverable = 'profile_pref_discoverable';
  static const _showOnline = 'profile_pref_show_online';

  Future<bool> _read(String key, {bool defaultValue = true}) async {
    final v = await _storage.read(key: key);
    if (v == null) {
      return defaultValue;
    }
    return v == '1';
  }

  Future<void> _write(String key, bool value) =>
      _storage.write(key: key, value: value ? '1' : '0');

  Future<bool> pushEnabled() => _read(_push);
  Future<bool> emailUpdatesEnabled() => _read(_email);
  Future<bool> sessionRemindersEnabled() => _read(_sessionReminders);
  Future<bool> chatAlertsEnabled() => _read(_chatAlerts);
  Future<bool> discoverable() => _read(_discoverable);
  Future<bool> showOnlineStatus() => _read(_showOnline, defaultValue: true);

  Future<void> setPush(bool v) => _write(_push, v);
  Future<void> setEmailUpdates(bool v) => _write(_email, v);
  Future<void> setSessionReminders(bool v) => _write(_sessionReminders, v);
  Future<void> setChatAlerts(bool v) => _write(_chatAlerts, v);
  Future<void> setDiscoverable(bool v) => _write(_discoverable, v);
  Future<void> setShowOnlineStatus(bool v) => _write(_showOnline, v);
}
